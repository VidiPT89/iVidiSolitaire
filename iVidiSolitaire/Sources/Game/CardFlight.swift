import CoreGraphics
import Foundation

/// A card's place on the board, with enough of its pile's makeup to work out the
/// exact on-screen rect later (tableau offsets depend on which cards above are face down).
struct PileSlot: Equatable {
    let pile: PileKind
    let index: Int
    let pileFaceUps: [Bool]

    init(pile: PileKind, index: Int, in state: GameState) {
        self.pile = pile
        self.index = index
        self.pileFaceUps = state.pile(pile).map(\.isFaceUp)
    }
}

/// One card travelling from where it was to where it now is. While a flight is active the
/// real card stays hidden in its new pile and a copy is drawn flying above the whole board,
/// so it can never slip behind a neighbouring pile.
struct CardFlight: Identifiable, Equatable {
    let token: Int
    let fromCard: Card
    let toCard: Card
    let from: PileSlot
    let to: PileSlot
    /// Exact starting rect, used when the card leaves from wherever the player dropped it.
    let fromRect: CGRect?
    let delay: Double

    var id: Int { token }
    var cardID: UUID { toCard.id }

    static let duration: Double = 0.34

    /// Every card that changed pile between `old` and `new`. Cards that didn't exist in `old`
    /// (a fresh deal) fly in from the stock in the order a dealer would lay them out.
    static func diff(
        from old: GameState,
        to new: GameState,
        startRects: [UUID: CGRect] = [:],
        stagger: Double = 0,
        nextToken: () -> Int
    ) -> [CardFlight] {
        var oldLocations: [UUID: (PileKind, Int, Card)] = [:]
        for kind in GameState.allPiles {
            for (index, card) in old.pile(kind).enumerated() {
                oldLocations[card.id] = (kind, index, card)
            }
        }

        var flights: [CardFlight] = []
        var movedCount = 0
        for kind in GameState.allPiles {
            for (index, card) in new.pile(kind).enumerated() {
                let target = PileSlot(pile: kind, index: index, in: new)
                if let (oldKind, oldIndex, oldCard) = oldLocations[card.id] {
                    guard oldKind != kind else { continue }
                    flights.append(CardFlight(
                        token: nextToken(),
                        fromCard: oldCard,
                        toCard: card,
                        from: PileSlot(pile: oldKind, index: oldIndex, in: old),
                        to: target,
                        fromRect: startRects[card.id],
                        delay: Double(movedCount) * stagger
                    ))
                    movedCount += 1
                } else if case .tableau(let column) = kind {
                    var faceDown = card
                    faceDown.isFaceUp = false
                    flights.append(CardFlight(
                        token: nextToken(),
                        fromCard: faceDown,
                        toCard: card,
                        from: PileSlot(pile: .stock, index: max(new.stock.count - 1, 0), in: new),
                        to: target,
                        fromRect: nil,
                        delay: 0.15 + Double(dealOrder(column: column, row: index)) * 0.035
                    ))
                }
            }
        }
        return flights
    }

    /// Position of a card in a row-by-row Klondike deal (row 0 across all 7 columns first).
    private static func dealOrder(column: Int, row: Int) -> Int {
        (0..<row).reduce(0) { $0 + (7 - $1) } + (column - row)
    }
}
