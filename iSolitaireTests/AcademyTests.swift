import XCTest
@testable import iSolitaire

@MainActor
final class AcademyTests: XCTestCase {
    private var suiteName = ""

    override func setUp() async throws {
        suiteName = "iSolitaireTests.\(UUID().uuidString)"
        GameStateStore.defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() async throws {
        GameStateStore.defaults.removePersistentDomain(forName: suiteName)
        GameStateStore.defaults = .standard
    }

    private var allExercises: [Exercise] { Academy.lessons.flatMap(\.exercises) }

    /// Every legal move (and the draw, if possible) on a position, in exercise terms.
    private func legalAnswers(_ state: GameState) -> [(ExerciseAnswer, Move?)] {
        var result: [(ExerciseAnswer, Move?)] = []
        var sources: [(Card, PileKind)] = []
        if let top = state.waste.last { sources.append((top, .waste)) }
        for column in state.tableau.indices {
            for card in state.tableau[column] where card.isFaceUp { sources.append((card, .tableau(column))) }
        }
        for (card, source) in sources {
            if state.canMove(cardID: card.id, from: source, to: .foundation(card.suit)) {
                result.append((.move(card: card.code, to: .foundation), Move(cardID: card.id, source: source, destination: .foundation(card.suit))))
            }
            for column in state.tableau.indices where state.canMove(cardID: card.id, from: source, to: .tableau(column)) {
                result.append((.move(card: card.code, to: .column(column)), Move(cardID: card.id, source: source, destination: .tableau(column))))
            }
        }
        if !state.stock.isEmpty { result.append((.draw, nil)) }
        return result
    }

    func testEveryExerciseIsAValidPosition() {
        XCTAssertEqual(Academy.lessons.count, 7)
        XCTAssertEqual(Set(allExercises.map(\.id)).count, allExercises.count, "exercise ids are unique")
        for exercise in allExercises {
            let state = exercise.makeState()
            let codes = GameState.allPiles.flatMap { state.pile($0) }.map(\.code)
            XCTAssertEqual(Set(codes).count, codes.count, "\(exercise.id): a card appears twice")
            XCTAssertEqual(state.tableau.count, 7, exercise.id)
            XCTAssertEqual(exercise.tableau.joined(separator: " ").split(separator: " ").count,
                           state.tableau.flatMap { $0 }.count, "\(exercise.id): a card code didn't parse")
        }
    }

    func testEveryAnswerAndEveryDescribedMistakeIsLegal() {
        for exercise in allExercises {
            let legal = legalAnswers(exercise.makeState()).map(\.0)
            XCTAssertTrue(legal.contains { exercise.answer.accepts($0) }, "\(exercise.id): the answer isn't a legal move")
            for mistake in exercise.mistakes.keys {
                XCTAssertTrue(legal.contains { mistake.accepts($0) }, "\(exercise.id): described mistake \(mistake) isn't legal")
                XCTAssertFalse(legal.filter { mistake.accepts($0) }.contains { exercise.answer.accepts($0) },
                               "\(exercise.id): a mistake overlaps the answer")
            }
        }
    }

    func testTheAnswerIsWhatTheCoachWouldRecommend() {
        // Each answer must not draw a warning from the table coach, so the lessons and the coach agree.
        for exercise in allExercises {
            let state = exercise.makeState()
            guard let (_, move) = legalAnswers(state).first(where: { exercise.answer.accepts($0.0) }) else { continue }
            let verdict = state.coachVerdict(for: move.map { .move($0) } ?? .draw)
            XCTAssertTrue(verdict == nil || verdict!.isPraise, "\(exercise.id): coach objects to the answer with \(String(describing: verdict))")
        }
    }

    func testWrongMoveIsExplainedAndNotPlayed() {
        let exercise = Academy.lesson(id: "aces")!.exercises[0]
        let game = GameModel(exercise: exercise)
        let start = game.state
        let five = game.state.tableau[1].last!
        XCTAssertFalse(game.tryMove(cardID: five.id, from: .tableau(1), to: .tableau(3)))
        XCTAssertEqual(game.state, start)
        guard case .wrong(let text) = game.practiceFeedback else { return XCTFail("expected feedback") }
        XCTAssertTrue(text.pt.contains("5♠"))
        XCTAssertFalse(game.practiceSolved)
    }

    func testRightMoveSolvesTheExerciseAndStarsCountSlips() {
        let exercise = Academy.lesson(id: "aces")!.exercises[0]
        let game = GameModel(exercise: exercise)
        let five = game.state.tableau[1].last!
        game.tryMove(cardID: five.id, from: .tableau(1), to: .tableau(3))
        let ace = game.state.tableau[0].last!
        game.smartMove(cardID: ace.id, from: .tableau(0))
        XCTAssertTrue(game.practiceSolved)
        XCTAssertEqual(game.state.foundations[.hearts]?.count, 1)
        XCTAssertEqual(game.practiceStars, 2)
        XCTAssertNil(GameStateStore.loadState(), "exercises never overwrite the saved game")
    }

    func testDrawExercise() {
        let exercise = Academy.lesson(id: "stock")!.exercises[0]
        let game = GameModel(exercise: exercise)
        game.drawFromStock()
        XCTAssertTrue(game.practiceSolved)
        XCTAssertEqual(game.practiceStars, 3)
    }

    func testProgressKeepsTheBestStars() {
        let lesson = Academy.lesson(id: "aces")!
        AcademyProgress.record(1, for: lesson.exercises[0].id)
        XCTAssertEqual(AcademyProgress.stars(for: lesson), 0, "not complete until every exercise is done")
        AcademyProgress.record(3, for: lesson.exercises[1].id)
        AcademyProgress.record(3, for: lesson.exercises[0].id)
        AcademyProgress.record(2, for: lesson.exercises[0].id)
        XCTAssertEqual(AcademyProgress.stars(for: lesson), 3)
        XCTAssertEqual(AcademyProgress.completedLessons(), 1)
    }

    // MARK: - Coach

    private func card(_ code: String, up: Bool = true) -> Card {
        var c = Card(code: code)!
        c.isFaceUp = up
        return c
    }

    func testCoachWarnsAboutAMissedReveal() {
        var state = GameState()
        for suit in Suit.allCases { state.foundations[suit] = [] }
        let nine = card("9H")
        state.tableau[0] = [card("TS")]
        state.tableau[1] = [card("4C", up: false), nine]
        state.tableau[2] = [card("TC")]
        state.waste = [card("9D")]
        let wasteMove = Move(cardID: state.waste[0].id, source: .waste, destination: .tableau(2))
        XCTAssertEqual(state.coachVerdict(for: .move(wasteMove)), .missedReveal(nine))
        XCTAssertNil(state.coachVerdict(for: .move(Move(cardID: nine.id, source: .tableau(1), destination: .tableau(0)))))
    }

    func testCoachWarnsAboutEmptyingAColumnWithoutAKing() {
        var state = GameState()
        for suit in Suit.allCases { state.foundations[suit] = [] }
        let five = card("5H")
        state.tableau[0] = [five]
        state.tableau[1] = [card("2D", up: false), card("6S")]
        XCTAssertEqual(state.coachVerdict(for: .move(Move(cardID: five.id, source: .tableau(0), destination: .tableau(1)))), .emptiedWithoutKing)
        state.waste = [card("KH")]
        XCTAssertNil(state.coachVerdict(for: .move(Move(cardID: five.id, source: .tableau(0), destination: .tableau(1)))))
    }

    func testHintExplainsItself() {
        let state = Academy.lesson(id: "aces")!.exercises[0].makeState()
        let move = state.usefulMoves().first
        guard case .toFoundation(let card) = state.hintReason(for: move) else { return XCTFail() }
        XCTAssertEqual(card.code, "AH")
        XCTAssertFalse(L10n.coachText(.hint(state.hintReason(for: move)), .portuguese).isEmpty)
    }
}
