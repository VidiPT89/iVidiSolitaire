import SwiftUI

/// What every pile needs from the board besides the game itself.
struct PileContext {
    let layout: BoardLayout
    /// Cards currently picked up by the player (drawn in the drag overlay instead).
    let draggedIDs: Set<UUID>
    /// The pile the dragged cards would land on if released now.
    let dropTarget: PileKind?
    let textColor: Color
    let cardGesture: (Card, PileKind) -> AnyGesture<DragGesture.Value>

    var metrics: CardMetrics { layout.metrics }
}

/// Outline shown where a pile is empty, plus the glow used for hint and drop targets.
private struct PilePlaceholder<Content: View>: View {
    let metrics: CardMetrics
    let color: Color
    var glowing = false
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: metrics.width * 0.11, style: .continuous)
        ZStack {
            shape.fill(Color.black.opacity(0.12))
            shape.strokeBorder(color.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            content.foregroundStyle(color.opacity(0.32))
        }
        .frame(width: metrics.width, height: metrics.height)
        .overlay { if glowing { TargetGlow(metrics: metrics) } }
    }
}

private struct TargetGlow: View {
    let metrics: CardMetrics
    var body: some View {
        RoundedRectangle(cornerRadius: metrics.width * 0.11, style: .continuous)
            .strokeBorder(Theme.gold, lineWidth: 2.5)
            .shadow(color: Theme.gold.opacity(0.8), radius: 6)
            .frame(width: metrics.width, height: metrics.height)
            .allowsHitTesting(false)
    }
}

private extension GameModel {
    func isHidden(_ card: Card, _ context: PileContext) -> Bool {
        isFlying(card.id) || context.draggedIDs.contains(card.id)
    }
}

// MARK: - Stock

struct StockView: View {
    @ObservedObject var game: GameModel
    let context: PileContext
    @Environment(\.appLanguage) private var language

    var body: some View {
        let metrics = context.metrics
        let stock = game.state.stock
        ZStack {
            PilePlaceholder(metrics: metrics, color: context.textColor, glowing: game.hint?.stock == true && stock.isEmpty) {
                Image(systemName: game.state.canRecycle(game.settings) || game.state.waste.isEmpty ? "arrow.counterclockwise" : "xmark")
                    .font(.system(size: metrics.width * 0.34, weight: .semibold))
            }

            // A couple of offset backs give the pile some thickness.
            ForEach(Array(stock.suffix(3).enumerated()), id: \.element.id) { offset, card in
                let depth = CGFloat(min(stock.count, 3) - 1 - offset)
                CardView(card: card, width: metrics.width)
                    .offset(x: -depth * 1.2, y: -depth * 1.2)
                    .opacity(game.isFlying(card.id) ? 0 : 1)
            }

            if game.hint?.stock == true, !stock.isEmpty {
                TargetGlow(metrics: metrics)
            }
        }
        .frame(width: metrics.width, height: metrics.height)
        .overlay(alignment: .bottom) {
            if !stock.isEmpty || game.settings.recycleMode == .limited {
                badge
                    .offset(y: -metrics.width * 0.06)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { game.drawFromStock() }
        .reportPileFrame(.stock)
        .accessibilityElement()
        .accessibilityLabel(L10n.t(.stock, language))
        .accessibilityValue("\(stock.count)")
        .accessibilityAddTraits(.isButton)
    }

    private var badge: some View {
        let stock = game.state.stock
        let settings = game.settings
        let text: String = {
            if !stock.isEmpty { return "\(stock.count)" }
            return "\(max(settings.recycleLimit - game.state.recyclesUsed, 0))↺"
        }()
        return Text(text)
            .font(.system(size: max(9, context.metrics.width * 0.2), weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(Color.black.opacity(0.55)))
    }
}

// MARK: - Waste

struct WasteView: View {
    @ObservedObject var game: GameModel
    let context: PileContext

    var body: some View {
        let layout = context.layout
        let waste = game.state.waste
        let visible = Array(waste.enumerated()).suffix(3)
        ZStack(alignment: layout.leftHanded ? .topTrailing : .topLeading) {
            RoundedRectangle(cornerRadius: layout.metrics.width * 0.11, style: .continuous)
                .strokeBorder(context.textColor.opacity(0.14), lineWidth: 1)
                .frame(width: layout.metrics.width, height: layout.metrics.height)
            ForEach(visible, id: \.element.id) { index, card in
                let isTop = index == waste.count - 1
                CardView(
                    card: card,
                    width: layout.metrics.width,
                    isHinted: game.hint?.cardIDs.contains(card.id) == true,
                    shakeTrigger: game.shakeCounts[card.id] ?? 0
                )
                .offset(x: layout.wasteOffset(index: index, count: waste.count))
                .transition(.identity)
                .opacity(game.isHidden(card, context) ? 0 : 1)
                .allowsHitTesting(isTop && !game.isHidden(card, context))
                .gesture(context.cardGesture(card, .waste))
                .accessibilityHidden(!isTop)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { game.smartMove(cardID: card.id, from: .waste) }
            }
        }
        .frame(width: layout.wasteWidth, height: layout.metrics.height)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: waste.count)
        .reportPileFrame(.waste)
    }
}

// MARK: - Foundation

struct FoundationView: View {
    @ObservedObject var game: GameModel
    let suit: Suit
    let context: PileContext

    var body: some View {
        let kind = PileKind.foundation(suit)
        let pile = game.state.foundations[suit] ?? []
        let glowing = context.dropTarget == kind || game.hint?.destination == kind
        ZStack {
            PilePlaceholder(metrics: context.metrics, color: context.textColor) {
                Image(systemName: suit.symbolName)
                    .font(.system(size: context.metrics.width * 0.42))
            }
            // The card underneath stays drawn so lifting the top one reveals it.
            ForEach(pile.suffix(2)) { card in
                CardView(card: card, width: context.metrics.width)
                    .opacity(game.isHidden(card, context) ? 0 : 1)
                    .transition(.identity)
                    .allowsHitTesting(card.id == pile.last?.id && !game.isHidden(card, context))
                    .gesture(context.cardGesture(card, kind))
            }
            if glowing { TargetGlow(metrics: context.metrics) }
        }
        .frame(width: context.metrics.width, height: context.metrics.height)
        .reportPileFrame(kind)
    }
}

// MARK: - Tableau

struct TableauColumnView: View {
    @ObservedObject var game: GameModel
    let column: Int
    let context: PileContext

    var body: some View {
        let kind = PileKind.tableau(column)
        let pile = game.state.tableau[column]
        let offsets = context.layout.tableauOffsets(pile.map(\.isFaceUp))
        let glowing = context.dropTarget == kind || game.hint?.destination == kind
        ZStack(alignment: .top) {
            PilePlaceholder(metrics: context.metrics, color: context.textColor, glowing: glowing && pile.isEmpty) {
                Text("K")
                    .font(.system(size: context.metrics.width * 0.4, weight: .bold, design: .serif))
            }

            ForEach(Array(pile.enumerated()), id: \.element.id) { index, card in
                let isLastCard = index == pile.count - 1
                CardView(
                    card: card,
                    width: context.metrics.width,
                    isHinted: game.hint?.cardIDs.contains(card.id) == true,
                    shakeTrigger: game.shakeCounts[card.id] ?? 0
                )
                .overlay {
                    if glowing && isLastCard { TargetGlow(metrics: context.metrics) }
                }
                .offset(y: offsets.indices.contains(index) ? offsets[index] : 0)
                .transition(.identity)
                .opacity(game.isHidden(card, context) ? 0 : 1)
                .allowsHitTesting(card.isFaceUp && !game.isHidden(card, context))
                .gesture(context.cardGesture(card, kind))
                .accessibilityAddTraits(card.isFaceUp ? .isButton : [])
                .accessibilityAction { if card.isFaceUp { game.smartMove(cardID: card.id, from: kind) } }
                .zIndex(Double(index))
            }
        }
        .frame(width: context.metrics.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: offsets)
        .reportPileFrame(kind)
    }
}

// MARK: - Overlays

/// The card (or run) the player is dragging, drawn above every pile.
struct DragPreviewOverlay: View {
    let preview: DragPreview

    var body: some View {
        let rect = preview.topCardRect
        ZStack(alignment: .top) {
            ForEach(Array(preview.cards.enumerated()), id: \.element.id) { index, card in
                CardView(card: card, width: preview.metrics.width, isLifted: true)
                    .offset(y: CGFloat(index) * preview.metrics.faceUpGap)
            }
        }
        .frame(width: rect.width, height: rect.height, alignment: .top)
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
    }
}

/// Copies of cards travelling between piles. Each one is drawn here, above the whole board,
/// while its real counterpart stays hidden in the destination pile until it lands.
struct FlightLayer: View {
    let flights: [CardFlight]
    let layout: BoardLayout
    let frames: [PileKind: CGRect]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            ForEach(flights.sorted { ($0.delay, $0.to.index) < ($1.delay, $1.to.index) }) { flight in
                if let from = flight.fromRect ?? layout.rect(for: flight.from, frames: frames),
                   let to = layout.rect(for: flight.to, frames: frames) {
                    FlyingCard(flight: flight, from: from, to: to, width: layout.metrics.width)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct FlyingCard: View {
    let flight: CardFlight
    let from: CGRect
    let to: CGRect
    let width: CGFloat

    @State private var arrived = false
    @State private var turned = false

    var body: some View {
        let rect = arrived ? to : from
        CardView(card: turned ? flight.toCard : flight.fromCard, width: width, isLifted: !arrived)
            .position(x: rect.midX, y: rect.midY)
            .onAppear {
                withAnimation(.spring(response: CardFlight.duration, dampingFraction: 0.86).delay(flight.delay)) {
                    arrived = true
                }
                if flight.fromCard.isFaceUp != flight.toCard.isFaceUp {
                    DispatchQueue.main.asyncAfter(deadline: .now() + flight.delay + 0.04) { turned = true }
                }
            }
    }
}
