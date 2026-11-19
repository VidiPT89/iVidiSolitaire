import Foundation

/// Snapshot of the whole board, used for undo and persistence.
struct GameState: Codable, Equatable {
    var tableau: [[Card]] = Array(repeating: [], count: 7)
    var foundations: [Suit: [Card]] = [:]
    var stock: [Card] = []
    var waste: [Card] = []
    var score: Int = 0
    var moves: Int = 0
    var elapsedSeconds: Int = 0
    var recyclesUsed: Int = 0
    /// How many times the player undid a move this game (a win without undo unlocks an achievement).
    var undosUsed: Int = 0

    init(tableau: [[Card]] = Array(repeating: [], count: 7), foundations: [Suit: [Card]] = [:], stock: [Card] = [], waste: [Card] = [],
         score: Int = 0, moves: Int = 0, elapsedSeconds: Int = 0, recyclesUsed: Int = 0, undosUsed: Int = 0) {
        self.tableau = tableau
        self.foundations = foundations
        self.stock = stock
        self.waste = waste
        self.score = score
        self.moves = moves
        self.elapsedSeconds = elapsedSeconds
        self.recyclesUsed = recyclesUsed
        self.undosUsed = undosUsed
    }

    // Counters are decoded leniently so a save from an older or newer version still loads
    // instead of silently throwing the player's game away.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tableau = try c.decode([[Card]].self, forKey: .tableau)
        foundations = try c.decode([Suit: [Card]].self, forKey: .foundations)
        stock = try c.decode([Card].self, forKey: .stock)
        waste = try c.decode([Card].self, forKey: .waste)
        score = try c.decodeIfPresent(Int.self, forKey: .score) ?? 0
        moves = try c.decodeIfPresent(Int.self, forKey: .moves) ?? 0
        elapsedSeconds = try c.decodeIfPresent(Int.self, forKey: .elapsedSeconds) ?? 0
        recyclesUsed = try c.decodeIfPresent(Int.self, forKey: .recyclesUsed) ?? 0
        undosUsed = try c.decodeIfPresent(Int.self, forKey: .undosUsed) ?? 0
    }

    var isWon: Bool {
        foundations.values.reduce(0) { $0 + $1.count } == 52
    }
}
