import Foundation

/// Persists the in-progress game, its undo history and the settings so the app can resume
/// exactly where the player left off.
enum GameStateStore {
    /// Swapped for an isolated suite in tests so they never touch the real saved game.
    static var defaults: UserDefaults = .standard

    private static let stateKey = "iVidiSolitaire.savedState"
    private static let historyKey = "iVidiSolitaire.undoHistory"
    private static let settingsKey = "iVidiSolitaire.savedSettings"

    /// How many undo steps survive the app being closed.
    static let savedHistoryLimit = 100

    private struct SavedHistory: Codable {
        let state: GameState
        let history: [GameState]
    }

    static func loadState() -> GameState? { load(GameState.self, stateKey) }

    static func saveState(_ state: GameState) { save(state, stateKey) }

    static func clearState() {
        defaults.removeObject(forKey: stateKey)
        defaults.removeObject(forKey: historyKey)
    }

    /// The undo history saved alongside `state`. It's only handed back if it was saved for
    /// exactly this board, so a stale history can never rewind into a different game.
    static func loadHistory(for state: GameState) -> [GameState] {
        guard let saved = load(SavedHistory.self, historyKey), saved.state == state else { return [] }
        return saved.history
    }

    static func saveHistory(_ history: [GameState], for state: GameState) {
        save(SavedHistory(state: state, history: Array(history.suffix(savedHistoryLimit))), historyKey)
    }

    static func loadSettings() -> GameSettings? { load(GameSettings.self, settingsKey) }

    static func saveSettings(_ settings: GameSettings) { save(settings, settingsKey) }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T, _ key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
