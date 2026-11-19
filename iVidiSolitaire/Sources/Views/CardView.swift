import SwiftUI

struct CardView: View {
    let card: Card
    var width: CGFloat = 64
    var isHinted: Bool = false
    var isLifted: Bool = false
    var shakeTrigger: Int = 0

    @Environment(\.cardBackStyle) private var backStyle
    @Environment(\.appLanguage) private var language
    @State private var flipAngle: Double = 0
    @State private var hintPulse = false

    private var height: CGFloat { width * CardMetrics.aspect }
    private var cornerRadius: CGFloat { width * 0.11 }
    private var inkColor: Color { card.suit.isRed ? Theme.cardRed : Theme.ink }

    var body: some View {
        ZStack {
            if flipAngle >= 90 {
                face.rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            } else {
                back
            }
        }
        .frame(width: width, height: height)
        .overlay {
            if isHinted {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.gold, lineWidth: max(2, width * 0.045))
                    .shadow(color: Theme.gold.opacity(0.9), radius: hintPulse ? 8 : 3)
            }
        }
        .compositingGroup()
        .shadow(
            color: .black.opacity(isLifted ? 0.4 : 0.22),
            radius: isLifted ? 10 : 1.2,
            x: 0,
            y: isLifted ? 8 : 0.8
        )
        .scaleEffect(isLifted ? 1.06 : (isHinted && hintPulse ? 1.05 : 1.0))
        .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        .keyframeAnimator(initialValue: CGFloat(0), trigger: shakeTrigger) { content, offset in
            content.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(-7, duration: 0.05)
                LinearKeyframe(6, duration: 0.07)
                LinearKeyframe(-4, duration: 0.07)
                LinearKeyframe(2, duration: 0.06)
                LinearKeyframe(0, duration: 0.05)
            }
        }
        .onAppear {
            flipAngle = card.isFaceUp ? 180 : 0
            startHintPulse(isHinted)
        }
        .onChange(of: card.isFaceUp) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) { flipAngle = newValue ? 180 : 0 }
        }
        .onChange(of: isHinted) { _, newValue in startHintPulse(newValue) }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isLifted)
        .accessibilityElement()
        .accessibilityLabel(card.isFaceUp ? L10n.cardName(card, language) : L10n.t(.faceDownCard, language))
    }

    private func startHintPulse(_ on: Bool) {
        if on {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { hintPulse = true }
        } else {
            hintPulse = false
        }
    }

    // MARK: - Face

    private var face: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(LinearGradient(colors: [.white, Theme.cream], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.16), lineWidth: 0.75)

            // The index sits in the strip that stays visible when cards overlap in a column.
            HStack(alignment: .center, spacing: 0) {
                Text(card.rank.label)
                    .font(.system(size: width * 0.36, weight: .bold, design: .rounded))
                    .tracking(card.rank == .ten ? -width * 0.035 : 0)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: card.suit.symbolName)
                    .font(.system(size: width * 0.25, weight: .semibold))
            }
            .foregroundStyle(inkColor)
            .padding(.horizontal, width * 0.08)
            .padding(.top, width * 0.04)
            .frame(width: width, height: width * 0.44)

            centerArt
                .frame(width: width, height: height - width * 0.44)
                .offset(y: width * 0.44)
        }
    }

    @ViewBuilder
    private var centerArt: some View {
        switch card.rank {
        case .ace:
            ZStack {
                if card.suit == .spades {
                    Circle()
                        .strokeBorder(inkColor.opacity(0.25), lineWidth: max(1, width * 0.02))
                        .frame(width: width * 0.62, height: width * 0.62)
                }
                Image(systemName: card.suit.symbolName)
                    .font(.system(size: width * (card.suit == .spades ? 0.4 : 0.5)))
                    .foregroundStyle(inkColor)
            }
            .offset(y: -width * 0.04)
        case .jack, .queen, .king:
            faceCardPanel
        default:
            if width >= 72 {
                PipGrid(count: card.rank.rawValue, symbol: card.suit.symbolName, color: inkColor, pipSize: width * 0.19)
                    .padding(.horizontal, width * 0.24)
                    .padding(.top, width * 0.13)
                    .padding(.bottom, width * 0.17)
            } else {
                Image(systemName: card.suit.symbolName)
                    .font(.system(size: width * 0.5))
                    .foregroundStyle(inkColor)
                    .offset(y: -width * 0.04)
            }
        }
    }

    private var faceCardPanel: some View {
        let emblem: String? = switch card.rank {
        case .king: "crown.fill"
        case .queen: "crown"
        default: nil
        }
        return ZStack {
            RoundedRectangle(cornerRadius: width * 0.07, style: .continuous)
                .fill(LinearGradient(colors: [inkColor.opacity(0.10), Theme.gold.opacity(0.22)], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: width * 0.07, style: .continuous)
                .strokeBorder(inkColor.opacity(0.35), lineWidth: max(1, width * 0.018))
            VStack(spacing: -width * 0.02) {
                if let emblem {
                    Image(systemName: emblem)
                        .font(.system(size: width * 0.16))
                        .foregroundStyle(Theme.scorched)
                }
                Text(card.rank.label)
                    .font(.system(size: width * 0.4, weight: .heavy, design: .serif))
                    .foregroundStyle(inkColor)
                if emblem == nil {
                    Image(systemName: card.suit.symbolName)
                        .font(.system(size: width * 0.14))
                        .foregroundStyle(inkColor.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, width * 0.12)
        .padding(.bottom, width * 0.1)
    }

    // MARK: - Back

    private var back: some View {
        let colors = backStyle.colors
        let ornament = backStyle.ornament
        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(LinearGradient(colors: [colors.0, colors.1], startPoint: .topLeading, endPoint: .bottomTrailing))
            CardBackLattice()
                .stroke(ornament.opacity(0.16), lineWidth: max(0.6, width * 0.012))
                .padding(width * 0.1)
                .clipShape(RoundedRectangle(cornerRadius: width * 0.06, style: .continuous))
            RoundedRectangle(cornerRadius: width * 0.06, style: .continuous)
                .strokeBorder(ornament.opacity(0.55), lineWidth: max(1, width * 0.022))
                .padding(width * 0.07)
            Circle()
                .fill(colors.1)
                .overlay(Circle().strokeBorder(ornament.opacity(0.6), lineWidth: max(1, width * 0.02)))
                .frame(width: width * 0.36, height: width * 0.36)
            Image(systemName: "suit.spade.fill")
                .font(.system(size: width * 0.17))
                .foregroundStyle(ornament.opacity(0.85))
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .center))
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.25), lineWidth: 0.75)
        }
    }
}

/// Standard pip arrangement for the number cards, used when cards are big enough (iPad, landscape).
private struct PipGrid: View {
    let count: Int
    let symbol: String
    let color: Color
    let pipSize: CGFloat

    private static let layouts: [Int: [CGPoint]] = {
        let third: CGFloat = 1.0 / 3.0
        let six = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 0.5), CGPoint(x: 1, y: 0.5), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)]
        let nineSides = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: third), CGPoint(x: 1, y: third),
                         CGPoint(x: 0, y: 2 * third), CGPoint(x: 1, y: 2 * third), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)]
        return [
            2: [CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 1)],
            3: [CGPoint(x: 0.5, y: 0), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 1)],
            4: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)],
            5: [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1)],
            6: six,
            7: six + [CGPoint(x: 0.5, y: 0.25)],
            8: six + [CGPoint(x: 0.5, y: 0.25), CGPoint(x: 0.5, y: 0.75)],
            9: nineSides + [CGPoint(x: 0.5, y: 0.5)],
            10: nineSides + [CGPoint(x: 0.5, y: third / 2), CGPoint(x: 0.5, y: 1 - third / 2)],
        ]
    }()

    var body: some View {
        GeometryReader { geo in
            ForEach(Array((Self.layouts[count] ?? []).enumerated()), id: \.offset) { _, point in
                Image(systemName: symbol)
                    .font(.system(size: pipSize))
                    .foregroundStyle(color)
                    .rotationEffect(.degrees(point.y > 0.5 ? 180 : 0))
                    .position(x: point.x * geo.size.width, y: point.y * geo.size.height)
            }
        }
    }
}

/// A diamond lattice drawn with straight lines, used as the card-back decoration.
private struct CardBackLattice: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step = max(rect.width / 5, 4)
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.maxY))
            path.move(to: CGPoint(x: x + rect.height, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            x += step
        }
        return path
    }
}

extension Suit {
    var symbolName: String {
        switch self {
        case .hearts: return "suit.heart.fill"
        case .diamonds: return "suit.diamond.fill"
        case .clubs: return "suit.club.fill"
        case .spades: return "suit.spade.fill"
        }
    }
}
