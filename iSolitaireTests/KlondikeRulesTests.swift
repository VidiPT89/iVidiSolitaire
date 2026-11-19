import XCTest
@testable import iSolitaire

final class KlondikeRulesTests: XCTestCase {
    private func card(_ rank: Rank, _ suit: Suit, up: Bool = true) -> Card {
        Card(suit: suit, rank: rank, isFaceUp: up)
    }

    private func emptyState() -> GameState {
        var state = GameState()
        for suit in Suit.allCases { state.foundations[suit] = [] }
        return state
    }

    private let settings = GameSettings()

    // MARK: - Deal

    func testNewDealLaysOutClassicKlondike() {
        let state = GameState.newDeal()
        XCTAssertEqual(state.tableau.map(\.count), [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(state.stock.count, 24)
        XCTAssertTrue(state.waste.isEmpty)
        for column in state.tableau {
            XCTAssertTrue(column.last!.isFaceUp)
            XCTAssertTrue(column.dropLast().allSatisfy { !$0.isFaceUp })
        }
        let all = state.tableau.flatMap { $0 } + state.stock
        XCTAssertEqual(Set(all.map(\.id)).count, 52)
    }

    // MARK: - Moves

    func testMoveRevealsCardAndScores() {
        var state = emptyState()
        let hidden = card(.two, .clubs, up: false)
        let seven = card(.seven, .hearts)
        let eight = card(.eight, .spades)
        state.tableau[0] = [hidden, seven]
        state.tableau[1] = [eight]

        XCTAssertTrue(state.apply(Move(cardID: seven.id, source: .tableau(0), destination: .tableau(1))))
        XCTAssertEqual(state.tableau[1].map(\.id), [eight.id, seven.id])
        XCTAssertTrue(state.tableau[0][0].isFaceUp, "card underneath should flip")
        XCTAssertEqual(state.score, 5)
        XCTAssertEqual(state.moves, 1)
    }

    func testIllegalMoveLeavesStateUntouched() {
        var state = emptyState()
        let seven = card(.seven, .hearts)
        let eight = card(.eight, .diamonds)
        state.tableau[0] = [seven]
        state.tableau[1] = [eight]
        let before = state
        XCTAssertFalse(state.apply(Move(cardID: seven.id, source: .tableau(0), destination: .tableau(1))))
        XCTAssertEqual(state, before)
    }

    func testOnlyKingsGoToEmptyColumns() {
        let state = emptyState()
        XCTAssertTrue(GameState.canStack(card(.king, .hearts), on: nil))
        XCTAssertFalse(GameState.canStack(card(.queen, .hearts), on: nil))
        XCTAssertTrue(state.canPlaceOnFoundation(card(.ace, .spades)))
        XCTAssertFalse(state.canPlaceOnFoundation(card(.two, .spades)))
    }

    func testFoundationToTableauScoreNeverGoesNegative() {
        var state = emptyState()
        let ace = card(.ace, .hearts)
        let two = card(.two, .spades)
        state.foundations[.hearts] = [ace]
        state.tableau[0] = [two]
        XCTAssertTrue(state.apply(Move(cardID: ace.id, source: .foundation(.hearts), destination: .tableau(0))))
        XCTAssertEqual(state.score, 0)
    }

    // MARK: - Stock

    func testRecyclingAnEmptyWasteDoesNothing() {
        var state = emptyState()
        XCTAssertFalse(state.draw(settings))
        XCTAssertEqual(state.recyclesUsed, 0)
        XCTAssertEqual(state.moves, 0)
    }

    func testDrawThreeAndLimitedRecycles() {
        var state = emptyState()
        state.stock = [card(.two, .clubs, up: false), card(.three, .clubs, up: false), card(.four, .clubs, up: false), card(.five, .clubs, up: false)]
        let limited = GameSettings(drawMode: .drawThree, recycleMode: .limited, recycleLimit: 1)

        XCTAssertTrue(state.draw(limited))
        XCTAssertEqual(state.waste.count, 3)
        XCTAssertTrue(state.draw(limited))
        XCTAssertEqual(state.waste.count, 4)
        XCTAssertTrue(state.draw(limited), "first recycle allowed")
        XCTAssertEqual(state.stock.count, 4)
        XCTAssertTrue(state.stock.allSatisfy { !$0.isFaceUp })
        XCTAssertTrue(state.draw(limited))
        XCTAssertTrue(state.draw(limited))
        XCTAssertFalse(state.draw(limited), "no recycles left")
    }

    // MARK: - Tap destination

    func testTapPrefersFoundationThenNonEmptyColumn() {
        var state = emptyState()
        let ace = card(.ace, .hearts)
        state.tableau[0] = [ace]
        XCTAssertEqual(state.bestDestination(for: ace.id, from: .tableau(0)), .foundation(.hearts))

        let queen = card(.queen, .hearts)
        let king = card(.king, .spades)
        state.tableau[1] = [card(.three, .clubs, up: false), queen]
        state.tableau[2] = [king]
        XCTAssertEqual(state.bestDestination(for: queen.id, from: .tableau(1)), .tableau(2))
    }

    func testTapDoesNotShuffleALoneKingBetweenEmptyColumns() {
        var state = emptyState()
        let king = card(.king, .spades)
        state.tableau[0] = [king]
        XCTAssertNil(state.bestDestination(for: king.id, from: .tableau(0)))

        state.tableau[0] = [card(.two, .clubs, up: false), king]
        XCTAssertEqual(state.bestDestination(for: king.id, from: .tableau(0)), .tableau(1))
    }

    // MARK: - Hints and stuck detection

    func testRunMoveThatRevealsACardCountsAsAMove() {
        // The top card (7♥) can't go anywhere, but the run 8♠-7♥ can move onto 9♦ and
        // reveal the face-down card. Earlier versions only checked top cards and wrongly
        // reported "no moves" here.
        var state = emptyState()
        let eight = card(.eight, .spades)
        state.tableau[0] = [card(.two, .clubs, up: false), eight, card(.seven, .hearts)]
        state.tableau[1] = [card(.nine, .diamonds)]
        XCTAssertEqual(state.usefulMoves().first, Move(cardID: eight.id, source: .tableau(0), destination: .tableau(1)))
        XCTAssertFalse(state.isStuck(settings))
    }

    func testStuckWhenNothingCanEverBePlayed() {
        var state = emptyState()
        state.tableau[0] = [card(.five, .clubs, up: false), card(.nine, .hearts)]
        state.tableau[1] = [card(.six, .clubs, up: false), card(.nine, .spades)]
        state.stock = [card(.four, .diamonds, up: false)]
        XCTAssertTrue(state.isStuck(settings))

        state.stock.append(card(.eight, .spades, up: false))
        XCTAssertFalse(state.isStuck(settings), "8♠ in the stock fits on 9♥")
    }

    func testCardsLeftInExhaustedWasteDoNotCount() {
        var state = emptyState()
        state.tableau[0] = [card(.five, .clubs, up: false), card(.nine, .hearts)]
        state.waste = [card(.eight, .spades), card(.four, .diamonds)]
        state.recyclesUsed = 1
        let limited = GameSettings(recycleMode: .limited, recycleLimit: 1)
        XCTAssertTrue(state.isStuck(limited), "8♠ is buried in the waste with no passes left")
        XCTAssertFalse(state.isStuck(settings), "with unlimited passes the 8♠ comes around again")
    }

    // MARK: - Auto-complete

    func testAutoCompleteFinishesIncludingTheStock() {
        var state = emptyState()
        var deck: [Card] = []
        for suit in Suit.allCases { for rank in Rank.allCases { deck.append(card(rank, suit)) } }
        // Kings and queens on the tableau, everything else in the stock face down.
        let high = deck.filter { $0.rank.rawValue >= 12 }
        state.tableau = Array(repeating: [], count: 7)
        for (i, c) in high.enumerated() { state.tableau[i % 7].append(c) }
        state.stock = deck.filter { $0.rank.rawValue < 12 }.reversed().map { var c = $0; c.isFaceUp = false; return c }

        guard let plan = state.autoCompletePlan(settings) else { return XCTFail("expected a plan") }
        for step in plan {
            switch step {
            case .move(let move): XCTAssertTrue(state.apply(move))
            case .draw: XCTAssertTrue(state.draw(settings))
            }
        }
        XCTAssertTrue(state.isWon)
    }

    func testNoAutoCompleteWhileCardsAreFaceDown() {
        var state = emptyState()
        state.tableau[0] = [card(.ace, .clubs, up: false), card(.two, .hearts)]
        XCTAssertNil(state.autoCompletePlan(settings))
    }

    // MARK: - Flights

    func testDiffFindsMovedCardsAndDealFlights() {
        let old = GameState.newDeal()
        var new = old
        new.draw(settings)
        var token = 0
        let flights = CardFlight.diff(from: old, to: new) { token += 1; return token }
        XCTAssertEqual(flights.count, 1)
        XCTAssertEqual(flights[0].from.pile, .stock)
        XCTAssertEqual(flights[0].to.pile, .waste)
        XCTAssertFalse(flights[0].fromCard.isFaceUp)
        XCTAssertTrue(flights[0].toCard.isFaceUp)

        let deal = CardFlight.diff(from: old, to: GameState.newDeal()) { token += 1; return token }
        XCTAssertEqual(deal.count, 28, "every tableau card is dealt from the stock")
    }

    func testStatsDecodeFromOlderVersion() throws {
        let json = #"{"gamesPlayed":3,"gamesWon":1,"currentWinStreak":1,"bestWinStreak":1,"bestScore":200}"#
        let stats = try JSONDecoder().decode(GameStats.self, from: Data(json.utf8))
        XCTAssertEqual(stats.gamesPlayed, 3)
        XCTAssertNil(stats.fewestMoves)
        XCTAssertEqual(stats.winRate, 33)
    }
}
