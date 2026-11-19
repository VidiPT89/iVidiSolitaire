import SwiftUI

/// Card proportions shared by every pile so the board scales to fit any screen.
struct CardMetrics: Equatable {
    static let aspect: CGFloat = 1.4

    let width: CGFloat
    var height: CGFloat { width * Self.aspect }
    var size: CGSize { CGSize(width: width, height: height) }
    /// Vertical step between face-up cards in a column: enough to read the rank and suit.
    var faceUpGap: CGFloat { height * 0.31 }
    /// Face-down cards only need a sliver showing.
    var faceDownGap: CGFloat { height * 0.11 }
    /// Horizontal step between the fanned waste cards in draw-three mode.
    var wasteFan: CGFloat { width * 0.3 }
}

/// Everything needed to turn a card's pile/index into an on-screen rect. Shared by the piles,
/// the flying-card layer and drag & drop so they always agree on where a card sits.
struct BoardLayout: Equatable {
    let metrics: CardMetrics
    /// Height available to the tableau; long columns squeeze their gaps to stay inside it.
    let tableauHeight: CGFloat
    let drawThree: Bool
    let leftHanded: Bool

    func tableauOffsets(_ faceUps: [Bool]) -> [CGFloat] {
        guard !faceUps.isEmpty else { return [] }
        var gaps = faceUps.dropLast().map { $0 ? metrics.faceUpGap : metrics.faceDownGap }
        let natural = gaps.reduce(0, +)
        let available = max(tableauHeight - metrics.height, 0)
        if natural > available, natural > 0 {
            let scale = max(available / natural, 0.2)
            gaps = gaps.map { $0 * scale }
        }
        var offsets: [CGFloat] = [0]
        for gap in gaps { offsets.append(offsets[offsets.count - 1] + gap) }
        return offsets
    }

    var wasteWidth: CGFloat { metrics.width + 2 * metrics.wasteFan }

    /// Horizontal offset of a waste card from the waste's anchor edge (only the top three fan out).
    func wasteOffset(index: Int, count: Int) -> CGFloat {
        guard drawThree else { return 0 }
        let firstVisible = count - min(3, count)
        let x = CGFloat(max(index - firstVisible, 0)) * metrics.wasteFan
        return leftHanded ? -x : x
    }

    func wasteCardX(index: Int, count: Int, in frame: CGRect) -> CGFloat {
        (leftHanded ? frame.maxX - metrics.width : frame.minX) + wasteOffset(index: index, count: count)
    }

    func rect(for slot: PileSlot, frames: [PileKind: CGRect]) -> CGRect? {
        guard let frame = frames[slot.pile] else { return nil }
        switch slot.pile {
        case .tableau:
            let offsets = tableauOffsets(slot.pileFaceUps)
            let y = offsets.indices.contains(slot.index) ? offsets[slot.index] : 0
            return CGRect(origin: CGPoint(x: frame.minX, y: frame.minY + y), size: metrics.size)
        case .waste:
            let x = wasteCardX(index: slot.index, count: slot.pileFaceUps.count, in: frame)
            return CGRect(origin: CGPoint(x: x, y: frame.minY), size: metrics.size)
        case .stock, .foundation:
            return CGRect(origin: frame.origin, size: metrics.size)
        }
    }
}

/// Tracks each pile's on-screen frame in the shared "board" coordinate space, so drag & drop
/// can hit-test drop locations and the flight layer can place cards exactly.
struct PileFramePreferenceKey: PreferenceKey {
    static var defaultValue: [PileKind: CGRect] = [:]
    static func reduce(value: inout [PileKind: CGRect], nextValue: () -> [PileKind: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    func reportPileFrame(_ kind: PileKind) -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: PileFramePreferenceKey.self, value: [kind: geo.frame(in: .named("board"))])
            }
        )
    }
}

/// A card (or run of cards) currently being dragged. Drawn in one board-level overlay so it
/// always paints above every pile, whichever column it's hovering over.
struct DragPreview {
    let cards: [Card]
    let source: PileKind
    /// Offset from the finger to the top card's top-left corner, so the card doesn't jump under the finger.
    let grabOffset: CGSize
    var location: CGPoint
    let metrics: CardMetrics

    var topCardRect: CGRect {
        CGRect(origin: CGPoint(x: location.x + grabOffset.width, y: location.y + grabOffset.height), size: metrics.size)
    }

    var cardRects: [UUID: CGRect] {
        Dictionary(uniqueKeysWithValues: cards.enumerated().map { index, card in
            (card.id, topCardRect.offsetBy(dx: 0, dy: CGFloat(index) * metrics.faceUpGap))
        })
    }
}
