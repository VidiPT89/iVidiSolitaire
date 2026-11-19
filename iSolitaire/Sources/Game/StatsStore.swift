import Foundation

struct GameStats: Codable, Equatable {
    var gamesPlayed: Int = 0
    var gamesWon: Int = 0
    var bestTimeSeconds: Int?
    var currentWinStreak: Int = 0
    var bestWinStreak: Int = 0
    var bestScore: Int = 0
    var fewestMoves: Int?
    var totalWinSeconds: Int = 0

    var winRate: Int {
        gamesPlayed == 0 ? 0 : Int((Double(gamesWon) / Double(gamesPlayed) * 100).rounded())
    }

    var averageWinSeconds: Int? {
        gamesWon == 0 ? nil : totalWinSeconds / gamesWon
    }

    init() {}

    // Decoded field by field so stats saved by older versions (without the newer fields) still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gamesPlayed = try c.decodeIfPresent(Int.self, forKey: .gamesPlayed) ?? 0
        gamesWon = try c.decodeIfPresent(Int.self, forKey: .gamesWon) ?? 0
        bestTimeSeconds = try c.decodeIfPresent(Int.self, forKey: .bestTimeSeconds)
        currentWinStreak = try c.decodeIfPresent(Int.self, forKey: .currentWinStreak) ?? 0
        bestWinStreak = try c.decodeIfPresent(Int.self, forKey: .bestWinStreak) ?? 0
        bestScore = try c.decodeIfPresent(Int.self, forKey: .bestScore) ?? 0
        fewestMoves = try c.decodeIfPresent(Int.self, forKey: .fewestMoves)
        totalWinSeconds = try c.decodeIfPresent(Int.self, forKey: .totalWinSeconds) ?? 0
    }
}

final class StatsStore {
    private let defaultsKey = "iSolitaire.stats"

    func load() -> GameStats {
        guard let data = GameStateStore.defaults.data(forKey: defaultsKey),
              let stats = try? JSONDecoder().decode(GameStats.self, from: data) else {
            return GameStats()
        }
        return stats
    }

    private func save(_ stats: GameStats) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        GameStateStore.defaults.set(data, forKey: defaultsKey)
    }

    /// Records a win and reports which personal bests it beat (a first win beats nothing).
    @discardableResult
    func recordWin(time: Int, score: Int, moves: Int) -> (isBestTime: Bool, isBestScore: Bool) {
        var stats = load()
        let isBestTime = stats.bestTimeSeconds.map { time < $0 } ?? false
        let isBestScore = stats.gamesWon > 0 && score > stats.bestScore
        stats.gamesPlayed += 1
        stats.gamesWon += 1
        stats.currentWinStreak += 1
        stats.bestWinStreak = max(stats.bestWinStreak, stats.currentWinStreak)
        stats.bestTimeSeconds = min(stats.bestTimeSeconds ?? Int.max, time)
        stats.bestScore = max(stats.bestScore, score)
        stats.fewestMoves = min(stats.fewestMoves ?? Int.max, moves)
        stats.totalWinSeconds += time
        save(stats)
        return (isBestTime, isBestScore)
    }

    func recordAbandon() {
        var stats = load()
        stats.gamesPlayed += 1
        stats.currentWinStreak = 0
        save(stats)
    }

    func reset() {
        GameStateStore.defaults.removeObject(forKey: defaultsKey)
    }
}
