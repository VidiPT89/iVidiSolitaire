import XCTest
@testable import iSolitaire

@MainActor
final class GameModelTests: XCTestCase {
    private var suiteName = ""

    override func setUp() async throws {
        suiteName = "iSolitaireTests.\(UUID().uuidString)"
        GameStateStore.defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() async throws {
        GameStateStore.defaults.removePersistentDomain(forName: suiteName)
        GameStateStore.defaults = .standard
    }

    private func card(_ rank: Rank, _ suit: Suit, up: Bool = true) -> Card {
        Card(suit: suit, rank: rank, isFaceUp: up)
    }

    /// A board one step from the end: every card on its foundation except the four kings,
    /// which sit face up on the tableau.
    private func almostWonState() -> GameState {
        var state = GameState()
        for suit in Suit.allCases {
            state.foundations[suit] = Rank.allCases.filter { $0 != .king }.map { card($0, suit) }
        }
        for (i, suit) in Suit.allCases.enumerated() { state.tableau[i] = [card(.king, suit)] }
        state.moves = 40
        return state
    }

    func testUndoRestoresTheBoardButNotTheClock() {
        let game = GameModel(startFresh: true)
        game.clock.seconds = 42
        let before = game.state
        game.drawFromStock()
        XCTAssertNotEqual(game.state.stock.count, before.stock.count)

        game.clock.seconds = 50
        game.undo()
        XCTAssertEqual(game.state.stock.map(\.id), before.stock.map(\.id))
        XCTAssertEqual(game.clock.seconds, 50, "undo must not wind the clock back")
        XCTAssertEqual(game.state.elapsedSeconds, 50)
    }

    func testStartingANewGameMidwayCountsAsAbandoned() {
        let game = GameModel(startFresh: true)
        game.drawFromStock()
        game.newGame()
        let stats = StatsStore().load()
        XCTAssertEqual(stats.gamesPlayed, 1)
        XCTAssertEqual(stats.gamesWon, 0)
        XCTAssertEqual(game.state.moves, 0)
        XCTAssertFalse(game.canUndo)
    }

    func testFreshDealIsNotCountedWhenReplaced() {
        let game = GameModel(startFresh: true)
        game.newGame()
        XCTAssertEqual(StatsStore().load().gamesPlayed, 0)
    }

    func testTapOnACardThatCannotMoveShakesItAndChangesNothing() {
        var state = GameState()
        let stuck = card(.five, .clubs)
        state.tableau[0] = [card(.two, .hearts, up: false), stuck]
        state.tableau[1] = [card(.nine, .hearts)]
        state.stock = [card(.ace, .spades, up: false)]
        GameStateStore.saveState(state)

        let game = GameModel()
        game.smartMove(cardID: stuck.id, from: .tableau(0))
        XCTAssertEqual(game.state, state)
        XCTAssertEqual(game.shakeCounts[stuck.id], 1)
        XCTAssertFalse(game.canUndo)
    }

    func testUndoHistorySurvivesClosingTheApp() {
        let first = GameModel(startFresh: true)
        let dealt = first.state
        first.drawFromStock()
        first.drawFromStock()
        first.pause()

        let reopened = GameModel()
        XCTAssertEqual(reopened.state.waste.count, 2)
        XCTAssertTrue(reopened.canUndo)
        reopened.undo()
        reopened.undo()
        XCTAssertEqual(reopened.state.stock.map(\.id), dealt.stock.map(\.id))
        XCTAssertFalse(reopened.canUndo)
    }

    func testStaleUndoHistoryIsIgnored() {
        let first = GameModel(startFresh: true)
        first.drawFromStock()
        first.pause()
        // A later move is saved without its history (as if the app was killed mid-game).
        first.drawFromStock()

        let reopened = GameModel()
        XCTAssertFalse(reopened.canUndo, "history saved for an older board must not be used")
    }

    func testAutoCompleteWinsAndRecordsTheWin() async throws {
        GameStateStore.saveState(almostWonState())
        let game = GameModel()
        XCTAssertTrue(game.autoCompleteAvailable)
        game.autoComplete()
        try await Task.sleep(nanoseconds: 1_500_000_000)

        XCTAssertTrue(game.state.isWon)
        XCTAssertEqual(game.winResult?.moves, 44)
        XCTAssertEqual(StatsStore().load().gamesWon, 1)
        XCTAssertNil(GameStateStore.loadState(), "a won game is not offered for resuming")
    }

    func testSavedGameFromAnOlderVersionStillLoads() throws {
        // No elapsedSeconds / recyclesUsed keys.
        var state = GameState()
        state.tableau[0] = [card(.king, .hearts)]
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
        json.removeValue(forKey: "elapsedSeconds")
        json.removeValue(forKey: "recyclesUsed")
        let decoded = try JSONDecoder().decode(GameState.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.tableau[0].first?.rank, .king)
        XCTAssertEqual(decoded.recyclesUsed, 0)

        let settings = try JSONDecoder().decode(GameSettings.self, from: Data(#"{"drawMode":"drawThree"}"#.utf8))
        XCTAssertEqual(settings.drawMode, .drawThree)
        XCTAssertEqual(settings.recycleLimit, 3)
    }
}
