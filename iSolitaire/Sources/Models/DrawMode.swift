import Foundation

enum DrawMode: String, CaseIterable, Codable {
    case drawOne
    case drawThree
}

enum RecycleMode: String, CaseIterable, Codable {
    case unlimited
    case limited
}

struct GameSettings: Codable, Equatable {
    var drawMode: DrawMode = .drawOne
    var recycleMode: RecycleMode = .unlimited
    var recycleLimit: Int = 3

    init(drawMode: DrawMode = .drawOne, recycleMode: RecycleMode = .unlimited, recycleLimit: Int = 3) {
        self.drawMode = drawMode
        self.recycleMode = recycleMode
        self.recycleLimit = recycleLimit
    }

    // Each field falls back to its default, so adding a setting never resets the others.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        drawMode = (try? c.decode(DrawMode.self, forKey: .drawMode)) ?? .drawOne
        recycleMode = (try? c.decode(RecycleMode.self, forKey: .recycleMode)) ?? .unlimited
        recycleLimit = (try? c.decode(Int.self, forKey: .recycleLimit)) ?? 3
    }
}
