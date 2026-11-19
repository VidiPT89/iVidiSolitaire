import Foundation

/// Something the player did on the table.
enum PlayerAction: Equatable {
    case move(Move)
    case draw
}

/// The coach's comment on a move, tied to the Academy lesson that teaches it.
enum CoachVerdict: Equatable {
    case foundationTooSoon(waiting: Card)
    case emptiedWithoutKing
    case missedTallerColumn(Card)
    case missedReveal(Card)
    case drewWithMoves(Card)
    case uncoveredFoundationCard
    case choseTallestColumn

    var isPraise: Bool {
        switch self {
        case .uncoveredFoundationCard, .choseTallestColumn: return true
        default: return false
        }
    }

    var lessonID: String {
        switch self {
        case .foundationTooSoon: return "foundations"
        case .emptiedWithoutKing: return "kings"
        case .missedTallerColumn, .choseTallestColumn: return "tallest"
        case .missedReveal: return "reveal"
        case .drewWithMoves: return "stock"
        case .uncoveredFoundationCard: return "split"
        }
    }
}

/// Why the hint points where it does.
enum HintReason: Equatable {
    case toFoundation(Card)
    case reveal(Card)
    case fromWaste(Card)
    case uncover(Card)
    case freeColumn(Card)
    case drawStock
}

extension GameState {
    /// Number of face-down cards in a column.
    func hiddenCount(_ column: Int) -> Int { tableau[column].filter { !$0.isFaceUp }.count }

    /// Whether a move turns over a face-down card in its source column.
    func reveals(_ move: Move) -> Bool {
        guard case .tableau(let column) = move.source,
              let index = tableau[column].firstIndex(where: { $0.id == move.cardID }), index > 0 else { return false }
        return !tableau[column][index - 1].isFaceUp
    }

    private func movingCard(_ move: Move) -> Card? {
        location(of: move.cardID).map { pile($0.pile)[$0.index] }
    }

    private func isEmptyingColumn(_ move: Move) -> Bool {
        guard case .tableau(let column) = move.source else { return false }
        return tableau[column].first?.id == move.cardID
    }

    /// A King that could move into an empty column: on the waste, or face up with cards under it.
    private var kingAvailable: Bool {
        if waste.last?.rank == .king { return true }
        return tableau.contains { column in
            column.dropFirst().contains { $0.isFaceUp && $0.rank == .king }
        }
    }

    private var revealingMoves: [Move] { usefulMoves().filter { reveals($0) } }

    /// The coach's view of a move, judged on the board as it was before the move.
    func coachVerdict(for action: PlayerAction) -> CoachVerdict? {
        guard case .move(let move) = action else {
            if let missed = usefulMoves().first(where: { reveals($0) || $0.destination.isFoundation }), let card = movingCard(missed) {
                return .drewWithMoves(card)
            }
            return nil
        }
        guard let location = location(of: move.cardID) else { return nil }
        let card = pile(location.pile)[location.index]

        if move.destination.isFoundation, let waiting = cardLeftStranded(bySending: card, from: move.source) {
            return .foundationTooSoon(waiting: waiting)
        }
        if isEmptyingColumn(move), !move.destination.isFoundation, !kingAvailable {
            return .emptiedWithoutKing
        }

        let revealing = revealingMoves
        if reveals(move), case .tableau(let column) = move.source {
            let others = revealing.compactMap { other -> (Move, Int)? in
                guard case .tableau(let otherColumn) = other.source, otherColumn != column else { return nil }
                return (other, hiddenCount(otherColumn))
            }
            if let taller = others.max(by: { $0.1 < $1.1 }), taller.1 > hiddenCount(column), let other = movingCard(taller.0) {
                return .missedTallerColumn(other)
            }
            if others.contains(where: { $0.1 < hiddenCount(column) }) {
                return .choseTallestColumn
            }
            return nil
        }

        let isLowCardUp = move.destination.isFoundation && card.rank.rawValue <= 2
        if !isLowCardUp, let missed = revealing.first, let other = movingCard(missed) {
            return .missedReveal(other)
        }

        if case .tableau(let column) = move.source, location.index > 0 {
            let below = tableau[column][location.index - 1]
            if below.isFaceUp, canPlaceOnFoundation(below) { return .uncoveredFoundationCard }
        }
        return nil
    }

    /// A tableau card (3 or higher) going to its foundation while an opposite-colour card one
    /// rank lower, sitting on hidden cards, has nowhere else to go.
    private func cardLeftStranded(bySending card: Card, from source: PileKind) -> Card? {
        guard card.rank.rawValue >= 3, case .tableau(let sourceColumn) = source else { return nil }
        for column in tableau.indices where column != sourceColumn {
            guard let baseIndex = tableau[column].firstIndex(where: \.isFaceUp), baseIndex > 0 else { continue }
            let base = tableau[column][baseIndex]
            guard Self.canStack(base, on: card) else { continue }
            let otherSpot = tableau.indices.contains { other in
                other != column && other != sourceColumn && Self.canStack(base, on: tableau[other].last)
            }
            if !otherSpot { return base }
        }
        return nil
    }

    /// Why the best useful move is worth making, for the hint text.
    func hintReason(for move: Move?) -> HintReason {
        guard let move, let location = location(of: move.cardID) else { return .drawStock }
        let card = pile(location.pile)[location.index]
        if move.destination.isFoundation { return .toFoundation(card) }
        if reveals(move) { return .reveal(card) }
        if move.source == .waste { return .fromWaste(card) }
        if isEmptyingColumn(move) { return .freeColumn(card) }
        return .uncover(card)
    }
}

extension PileKind {
    var isFoundation: Bool {
        if case .foundation = self { return true }
        return false
    }
}
