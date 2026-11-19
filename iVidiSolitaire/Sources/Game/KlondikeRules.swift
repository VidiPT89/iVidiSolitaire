import Foundation

/// A single card (or run of cards, starting at `cardID`) moving between two piles.
struct Move: Equatable {
    let cardID: UUID
    let source: PileKind
    let destination: PileKind
}

/// One step of an auto-complete plan: either a move to a foundation or a draw from the stock.
enum AutoCompleteStep: Equatable {
    case move(Move)
    case draw
}

/// Pure Klondike rules over a `GameState` snapshot. No UI, timers or side effects,
/// so every rule can be unit-tested directly.
extension GameState {

    // MARK: - Deal

    static func newDeal(deck: [Card] = Card.standardDeck().shuffled()) -> GameState {
        var deck = deck
        var tableau: [[Card]] = Array(repeating: [], count: 7)
        for column in 0..<7 {
            for row in 0...column {
                var card = deck.removeLast()
                card.isFaceUp = (row == column)
                tableau[column].append(card)
            }
        }
        var foundations: [Suit: [Card]] = [:]
        for suit in Suit.allCases { foundations[suit] = [] }
        return GameState(
            tableau: tableau,
            foundations: foundations,
            stock: deck.map { var c = $0; c.isFaceUp = false; return c }
        )
    }

    // MARK: - Piles

    func pile(_ kind: PileKind) -> [Card] {
        switch kind {
        case .stock: return stock
        case .waste: return waste
        case .foundation(let suit): return foundations[suit] ?? []
        case .tableau(let column): return tableau[column]
        }
    }

    static let allPiles: [PileKind] =
        [.stock, .waste] + Suit.allCases.map { .foundation($0) } + (0..<7).map { .tableau($0) }

    /// Where a card currently is, or nil if it isn't on the board.
    func location(of cardID: UUID) -> (pile: PileKind, index: Int)? {
        for kind in Self.allPiles {
            if let index = pile(kind).firstIndex(where: { $0.id == cardID }) {
                return (kind, index)
            }
        }
        return nil
    }

    // MARK: - Placement rules

    static func canStack(_ card: Card, on top: Card?) -> Bool {
        guard let top else { return card.rank == .king }
        return top.isFaceUp && top.suit.isRed != card.suit.isRed && top.rank.rawValue == card.rank.rawValue + 1
    }

    func canPlaceOnFoundation(_ card: Card) -> Bool {
        guard let last = foundations[card.suit]?.last else { return card.rank == .ace }
        return last.rank.rawValue + 1 == card.rank.rawValue
    }

    static func isValidRun(_ run: [Card]) -> Bool {
        guard run.allSatisfy(\.isFaceUp) else { return false }
        for (a, b) in zip(run, run.dropFirst()) {
            if a.suit.isRed == b.suit.isRed || a.rank.rawValue != b.rank.rawValue + 1 { return false }
        }
        return true
    }

    /// The cards that would move if the player picked up `cardID` from `source`.
    func run(startingAt cardID: UUID, in source: PileKind) -> [Card]? {
        switch source {
        case .waste, .foundation:
            let pile = pile(source)
            guard let card = pile.last, card.id == cardID else { return nil }
            return [card]
        case .tableau(let column):
            let pile = tableau[column]
            guard let index = pile.firstIndex(where: { $0.id == cardID }), pile[index].isFaceUp else { return nil }
            let run = Array(pile[index...])
            return Self.isValidRun(run) ? run : nil
        case .stock:
            return nil
        }
    }

    func canMove(_ run: [Card], to destination: PileKind) -> Bool {
        guard let first = run.first, Self.isValidRun(run) else { return false }
        switch destination {
        case .foundation(let suit):
            return run.count == 1 && first.suit == suit && canPlaceOnFoundation(first)
        case .tableau(let column):
            return Self.canStack(first, on: tableau[column].last)
        case .stock, .waste:
            return false
        }
    }

    func canMove(cardID: UUID, from source: PileKind, to destination: PileKind) -> Bool {
        guard source != destination, let run = run(startingAt: cardID, in: source) else { return false }
        return canMove(run, to: destination)
    }

    // MARK: - Applying moves

    static func scoreDelta(from source: PileKind, to destination: PileKind) -> Int {
        switch (source, destination) {
        case (.waste, .foundation), (.tableau, .foundation): return 10
        case (.foundation, .tableau): return -15
        case (.waste, .tableau): return 5
        default: return 0
        }
    }

    /// Applies a move if it's legal. Returns false (leaving the state untouched) otherwise.
    @discardableResult
    mutating func apply(_ move: Move) -> Bool {
        guard canMove(cardID: move.cardID, from: move.source, to: move.destination),
              let run = run(startingAt: move.cardID, in: move.source) else { return false }

        switch move.source {
        case .waste: waste.removeLast(run.count)
        case .foundation(let suit): foundations[suit]?.removeLast(run.count)
        case .tableau(let column): tableau[column].removeLast(run.count)
        case .stock: return false
        }
        switch move.destination {
        case .foundation(let suit): foundations[suit, default: []].append(contentsOf: run)
        case .tableau(let column): tableau[column].append(contentsOf: run)
        case .stock, .waste: return false
        }

        if case .tableau(let column) = move.source, let last = tableau[column].last, !last.isFaceUp {
            tableau[column][tableau[column].count - 1].isFaceUp = true
            score += 5
        }
        moves += 1
        score = max(0, score + Self.scoreDelta(from: move.source, to: move.destination))
        return true
    }

    func canRecycle(_ settings: GameSettings) -> Bool {
        guard stock.isEmpty, !waste.isEmpty else { return false }
        return settings.recycleMode == .unlimited || recyclesUsed < settings.recycleLimit
    }

    /// Draws from the stock, or turns the waste back over when the stock is empty.
    /// Returns false when there is nothing to draw and no recycle left.
    @discardableResult
    mutating func draw(_ settings: GameSettings) -> Bool {
        if stock.isEmpty {
            guard canRecycle(settings) else { return false }
            stock = waste.reversed().map { var c = $0; c.isFaceUp = false; return c }
            waste.removeAll()
            recyclesUsed += 1
            score = max(0, score - 20)
        } else {
            let count = settings.drawMode == .drawOne ? 1 : 3
            for _ in 0..<min(count, stock.count) {
                var card = stock.removeLast()
                card.isFaceUp = true
                waste.append(card)
            }
        }
        moves += 1
        return true
    }

    // MARK: - Analysis

    /// Destination a single tap on `cardID` should send it to, or nil if it can't go anywhere useful.
    /// Foundations first, then a non-empty column, then an empty one (never shuffling a whole
    /// column into another empty column, which changes nothing).
    func bestDestination(for cardID: UUID, from source: PileKind) -> PileKind? {
        guard let run = run(startingAt: cardID, in: source), let first = run.first else { return nil }
        if run.count == 1, source != .foundation(first.suit), canPlaceOnFoundation(first) {
            return .foundation(first.suit)
        }
        let isWholeColumn: Bool = {
            if case .tableau(let column) = source { return tableau[column].first?.id == cardID }
            return false
        }()
        let columns = tableauColumnsNonEmptyFirst(excluding: source)
        return columns.first { column in
            guard Self.canStack(first, on: tableau[column].last) else { return false }
            return !(tableau[column].isEmpty && isWholeColumn)
        }.map { .tableau($0) }
    }

    private func tableauColumnsNonEmptyFirst(excluding source: PileKind) -> [Int] {
        let others = tableau.indices.filter { source != .tableau($0) }
        return others.filter { !tableau[$0].isEmpty } + others.filter { tableau[$0].isEmpty }
    }

    /// Moves that make progress, best first: foundation moves, moves that reveal a
    /// face-down card (or free a column), waste to tableau, and partial-run moves that
    /// uncover a card ready for its foundation. Cosmetic moves are left out.
    func usefulMoves() -> [Move] {
        var result: [Move] = []

        for column in tableau.indices {
            if let top = tableau[column].last, top.isFaceUp, canPlaceOnFoundation(top) {
                result.append(Move(cardID: top.id, source: .tableau(column), destination: .foundation(top.suit)))
            }
        }
        if let top = waste.last, canPlaceOnFoundation(top) {
            result.append(Move(cardID: top.id, source: .waste, destination: .foundation(top.suit)))
        }

        var revealing: [Move] = []
        var freeing: [Move] = []
        for column in tableau.indices {
            let pile = tableau[column]
            guard let baseIndex = pile.firstIndex(where: \.isFaceUp) else { continue }
            let base = pile[baseIndex]
            let source = PileKind.tableau(column)
            guard Self.isValidRun(Array(pile[baseIndex...])) else { continue }
            for other in tableauColumnsNonEmptyFirst(excluding: source) {
                let target = tableau[other].last
                guard Self.canStack(base, on: target) else { continue }
                if target == nil && baseIndex == 0 { continue }
                let move = Move(cardID: base.id, source: source, destination: .tableau(other))
                if baseIndex > 0 { revealing.append(move) } else { freeing.append(move) }
                break
            }
        }
        result += revealing

        if let top = waste.last,
           let column = tableauColumnsNonEmptyFirst(excluding: .waste).first(where: { Self.canStack(top, on: tableau[$0].last) }) {
            result.append(Move(cardID: top.id, source: .waste, destination: .tableau(column)))
        }

        for column in tableau.indices {
            let pile = tableau[column]
            guard let baseIndex = pile.firstIndex(where: \.isFaceUp) else { continue }
            for index in pile.indices where index > baseIndex {
                guard canPlaceOnFoundation(pile[index - 1]) else { continue }
                let card = pile[index]
                if let other = tableauColumnsNonEmptyFirst(excluding: .tableau(column))
                    .first(where: { Self.canStack(card, on: tableau[$0].last) }) {
                    result.append(Move(cardID: card.id, source: .tableau(column), destination: .tableau(other)))
                }
            }
        }

        result += freeing
        return result
    }

    /// True when no useful move exists and no card still to come from the stock/waste
    /// could ever be played on the current board.
    func isStuck(_ settings: GameSettings) -> Bool {
        guard !isWon, usefulMoves().isEmpty else { return false }
        let canCycle = !stock.isEmpty || canRecycle(settings)
        let upcoming = canCycle ? stock + waste : []
        return !upcoming.contains { card in
            canPlaceOnFoundation(card) || tableau.indices.contains { Self.canStack(card, on: tableau[$0].last) }
        }
    }

    /// The lowest-ranked card that can go to a foundation right now (waste top or a tableau top).
    func nextFoundationMove() -> Move? {
        var candidates: [(Card, PileKind)] = []
        if let top = waste.last { candidates.append((top, .waste)) }
        for column in tableau.indices {
            if let top = tableau[column].last, top.isFaceUp { candidates.append((top, .tableau(column))) }
        }
        return candidates
            .filter { canPlaceOnFoundation($0.0) }
            .min { $0.0.rank.rawValue < $1.0.rank.rawValue }
            .map { Move(cardID: $0.0.id, source: $0.1, destination: .foundation($0.0.suit)) }
    }

    /// Once every tableau card is face up the game is decided: this returns the exact
    /// sequence of foundation moves and stock draws that finishes it, or nil if the
    /// board isn't there yet (or the remaining stock can't be reached under `settings`).
    func autoCompletePlan(_ settings: GameSettings) -> [AutoCompleteStep]? {
        guard !isWon, tableau.allSatisfy({ $0.allSatisfy(\.isFaceUp) }) else { return nil }
        var state = self
        var steps: [AutoCompleteStep] = []
        var drawsWithoutProgress = 0
        while !state.isWon {
            if let move = state.nextFoundationMove() {
                state.apply(move)
                steps.append(.move(move))
                drawsWithoutProgress = 0
                continue
            }
            let remaining = state.stock.count + state.waste.count
            guard remaining > 0, drawsWithoutProgress <= remaining + 1, state.draw(settings) else { return nil }
            steps.append(.draw)
            drawsWithoutProgress += 1
        }
        return steps
    }
}
