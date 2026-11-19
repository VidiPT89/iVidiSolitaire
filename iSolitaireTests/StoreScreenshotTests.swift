import XCTest
import SwiftUI
@testable import iSolitaire

/// Renders the App Store screenshots from the real views. Skipped unless a destination folder is given:
/// `TEST_RUNNER_STORE_SHOTS_DIR=/path xcodebuild test -only-testing:iSolitaireTests/StoreScreenshotTests`.
@MainActor
final class StoreScreenshotTests: XCTestCase {
    private struct Device {
        let name: String
        let points: CGSize
        let scale: CGFloat
        let insets: UIEdgeInsets
    }

    private let devices = [
        Device(name: "iphone", points: CGSize(width: 402, height: 874), scale: 3,
               insets: UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0)),
        Device(name: "ipad", points: CGSize(width: 1032, height: 1376), scale: 2,
               insets: UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0)),
    ]

    private let preferenceKeys = ["iSolitaire.language", "iSolitaire.tableTheme", "iSolitaire.cardBack", "iSolitaire.colorScheme"]
    private var suiteName = ""

    func testStoreScreenshots() async throws {
        guard let dir = ProcessInfo.processInfo.environment["STORE_SHOTS_DIR"] else {
            throw XCTSkip("STORE_SHOTS_DIR not set")
        }
        let standard = UserDefaults.standard
        let previous = preferenceKeys.map { standard.object(forKey: $0) }
        suiteName = "iSolitaireShots.\(UUID().uuidString)"
        GameStateStore.defaults = UserDefaults(suiteName: suiteName)!
        defer {
            for (key, value) in zip(preferenceKeys, previous) { standard.set(value, forKey: key) }
            GameStateStore.defaults.removePersistentDomain(forName: suiteName)
            GameStateStore.defaults = .standard
        }
        standard.set("dark", forKey: "iSolitaire.colorScheme")
        for (id, stars) in ["aces.1": 3, "aces.2": 3, "reveal.1": 3, "reveal.2": 2, "tallest.1": 2, "tallest.2": 3] {
            AcademyProgress.record(stars, for: id)
        }

        for (language, code) in [(AppLanguage.portuguese, "pt"), (AppLanguage.english, "en")] {
            standard.set(language.rawValue, forKey: "iSolitaire.language")
            for device in devices {
                let screens: [(String, TableTheme, CardBackStyle, () -> AnyView)] = [
                    ("1-academy", .ember, .ember, { AnyView(NavigationStack { AcademyView() }) }),
                    ("2-exercise", .felt, .crimson, { AnyView(self.exerciseAfterMistake()) }),
                    ("3-coach", .felt, .ember, { AnyView(self.gameWithCoachTip()) }),
                    ("4-hint", .ocean, .navy, { AnyView(self.gameWithHint()) }),
                    ("5-solved", .ember, .ember, { AnyView(self.solvedExercise()) }),
                    ("6-win", .wine, .onyx, { AnyView(self.winScreen()) }),
                ]
                for (name, theme, back, makeView) in screens {
                    standard.set(theme.rawValue, forKey: "iSolitaire.tableTheme")
                    standard.set(back.rawValue, forKey: "iSolitaire.cardBack")
                    let view = makeView()
                        .environmentObject(AppSettingsStore())
                        .environment(\.appLanguage, language)
                        .environment(\.cardBackStyle, back)
                    let image = try await render(AnyView(view), device: device)
                    let url = URL(fileURLWithPath: dir).appendingPathComponent("\(code)-\(device.name)-\(name).png")
                    try XCTUnwrap(image.pngData()).write(to: url)
                }
            }
        }
    }

    private func render(_ view: AnyView, device: Device) async throws -> UIImage {
        let host = UIHostingController(rootView: view)
        host.overrideUserInterfaceStyle = .dark
        host.additionalSafeAreaInsets = device.insets
        let window = UIWindow(frame: CGRect(origin: .zero, size: device.points))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 1_200_000_000)
        let format = UIGraphicsImageRendererFormat()
        format.scale = device.scale
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: device.points, format: format).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        return image
    }

    // MARK: - Prepared moments

    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    /// A game played forward a few moves from a fixed shuffle, so every run shows the same board.
    private func midGame(seed: UInt64, steps: Int) -> GameState {
        var generator = SeededGenerator(state: seed)
        var state = GameState.newDeal(deck: Card.standardDeck().shuffled(using: &generator))
        let settings = GameSettings()
        for _ in 0..<steps {
            if let move = state.usefulMoves().first { state.apply(move) } else { state.draw(settings) }
        }
        state.elapsedSeconds = 214
        return state
    }

    private func practice(_ exercise: Exercise, lesson: Lesson, step: Int) -> PracticeConfig {
        PracticeConfig(exercise: exercise, lessonTitle: lesson.title, step: step, total: lesson.exercises.count, onNext: { _ in }, onClose: {})
    }

    private func exerciseAfterMistake() -> some View {
        let lesson = Academy.lesson(id: "tallest")!
        let exercise = lesson.exercises[0]
        let game = GameModel(exercise: exercise)
        let seven = game.state.tableau[1].last!
        game.tryMove(cardID: seven.id, from: .tableau(1), to: .tableau(0))
        return BoardView(game: game, practice: practice(exercise, lesson: lesson, step: 1))
    }

    private func solvedExercise() -> some View {
        let lesson = Academy.lesson(id: "kings")!
        let exercise = lesson.exercises[2]
        let game = GameModel(exercise: exercise)
        let king = game.state.tableau[6].last!
        game.tryMove(cardID: king.id, from: .tableau(6), to: .tableau(3))
        return BoardView(game: game, practice: practice(exercise, lesson: lesson, step: 3))
    }

    /// The first fixed-shuffle position, a few moves in, that matches `condition`.
    private func findGame(_ condition: (GameState) -> Bool) -> GameState {
        for seed in UInt64(1)...400 {
            for steps in 8...16 {
                let state = midGame(seed: seed, steps: steps)
                if condition(state) { return state }
            }
        }
        return midGame(seed: 1, steps: 10)
    }

    private func gameWithCoachTip() -> some View {
        let state = findGame { state in
            guard state.stock.count > 4, state.foundations.values.map(\.count).reduce(0, +) >= 2 else { return false }
            guard case .drewWithMoves(let card) = state.coachVerdict(for: .draw) else { return false }
            return state.tableau.contains { $0.last?.id == card.id }
        }
        GameStateStore.saveState(state)
        let game = GameModel()
        game.drawFromStock()
        return NavigationStack { BoardView(game: game) }
    }

    private func gameWithHint() -> some View {
        let state = findGame { state in
            guard state.waste.count >= 3, let move = state.usefulMoves().first,
                  case .reveal = state.hintReason(for: move) else { return false }
            return state.tableau.contains { $0.filter(\.isFaceUp).count >= 3 }
        }
        GameStateStore.saveState(state)
        let game = GameModel()
        game.requestHint()
        return NavigationStack { BoardView(game: game) }
    }

    private func winScreen() -> some View {
        ZStack {
            TableBackground(theme: .wine, scheme: .dark)
            WinOverlay(result: WinResult(score: 735, seconds: 251, moves: 118, isBestTime: true, isBestScore: false), onPlayAgain: {}, onMenu: {})
        }
    }
}
