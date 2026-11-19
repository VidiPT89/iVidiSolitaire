import GameKit
import SwiftUI

/// Apple Game Center: signs the player in when the app starts, reports wins to the
/// leaderboards and unlocks achievements. Everything is a no-op until the player is signed in,
/// so the game works exactly the same without Game Center.
@MainActor
final class GameCenter: ObservableObject {
    static let shared = GameCenter()

    enum Leaderboard {
        static let highScore = "dev.ividi.isolitaire.highscore"
        static let fastestWin = "dev.ividi.isolitaire.fastest"
        static let totalWins = "dev.ividi.isolitaire.wins"
    }

    enum Achievement {
        static let firstWin = "dev.ividi.isolitaire.firstwin"
        static let tenWins = "dev.ividi.isolitaire.wins10"
        static let streak = "dev.ividi.isolitaire.streak3"
        static let fastWin = "dev.ividi.isolitaire.fastwin"
        static let drawThree = "dev.ividi.isolitaire.drawthree"
        static let noUndo = "dev.ividi.isolitaire.noundo"
        static let firstLesson = "dev.ividi.isolitaire.lesson"
        static let graduate = "dev.ividi.isolitaire.graduate"
    }

    /// A win under this many seconds unlocks the "fast win" achievement.
    static let fastWinSeconds = 180

    @Published private(set) var isAuthenticated = false
    /// Set by the menu: the access point badge only floats over the menu, never over the table.
    @Published var isMenuVisible = false { didSet { updateAccessPoint() } }
    @Published var isMenuCovered = false { didSet { updateAccessPoint() } }

    private var didStart = false

    private init() {}

    func authenticate() {
        guard !didStart else { return }
        didStart = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    Self.topViewController()?.present(viewController, animated: true)
                    return
                }
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                self.updateAccessPoint()
            }
        }
    }

    private func updateAccessPoint() {
        let access = GKAccessPoint.shared
        access.location = .topLeading
        let show = isAuthenticated && isMenuVisible && !isMenuCovered
        if access.isActive != show { access.isActive = show }
    }

    /// Opens Apple's Game Center screen on the leaderboards.
    func showLeaderboards() {
        guard isAuthenticated else { return }
        GKAccessPoint.shared.trigger(state: .leaderboards) {}
    }

    // MARK: - Reporting

    func reportWin(score: Int, seconds: Int, drawThree: Bool, usedUndo: Bool, stats: GameStats) {
        guard isAuthenticated else { return }
        submit(score, to: Leaderboard.highScore)
        submit(seconds, to: Leaderboard.fastestWin)
        submit(stats.gamesWon, to: Leaderboard.totalWins)

        var unlocked = [Achievement.firstWin]
        if seconds < Self.fastWinSeconds { unlocked.append(Achievement.fastWin) }
        if drawThree { unlocked.append(Achievement.drawThree) }
        if !usedUndo { unlocked.append(Achievement.noUndo) }
        if stats.currentWinStreak >= 3 { unlocked.append(Achievement.streak) }
        var progress = unlocked.map { achievement($0, percent: 100) }
        progress.append(achievement(Achievement.tenWins, percent: min(100, Double(stats.gamesWon) * 10)))
        GKAchievement.report(progress) { _ in }
    }

    func reportAcademy(completedLessons: Int, totalLessons: Int) {
        guard isAuthenticated, completedLessons > 0, totalLessons > 0 else { return }
        GKAchievement.report([
            achievement(Achievement.firstLesson, percent: 100),
            achievement(Achievement.graduate, percent: Double(completedLessons) / Double(totalLessons) * 100),
        ]) { _ in }
    }

    private func submit(_ value: Int, to leaderboard: String) {
        GKLeaderboard.submitScore(value, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboard]) { _ in }
    }

    private func achievement(_ id: String, percent: Double) -> GKAchievement {
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = percent
        achievement.showsCompletionBanner = true
        return achievement
    }

    private static func topViewController() -> UIViewController? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        var top = window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
