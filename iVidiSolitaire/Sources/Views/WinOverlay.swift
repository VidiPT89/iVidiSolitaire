import SwiftUI

struct WinOverlay: View {
    let result: WinResult
    let onPlayAgain: () -> Void
    let onMenu: () -> Void
    @EnvironmentObject var appSettings: AppSettingsStore
    @State private var appeared = false

    private var lang: AppLanguage { appSettings.language }

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.55 : 0).ignoresSafeArea()

            SuitConfetti().ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Theme.accentGradient)
                    .symbolEffect(.bounce, value: appeared)

                Text(L10n.t(.youWon, lang))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.cream)

                HStack(spacing: 10) {
                    stat(icon: "star.fill", value: "\(result.score)", label: L10n.t(.score, lang), record: result.isBestScore)
                    stat(icon: "clock.fill", value: L10n.time(result.seconds), label: L10n.t(.time, lang), record: result.isBestTime)
                    stat(icon: "hand.draw.fill", value: "\(result.moves)", label: L10n.t(.moves, lang), record: false)
                }

                if result.isBestScore || result.isBestTime {
                    Label(L10n.t(result.isBestTime ? .newBestTime : .newBestScore, lang), systemImage: "sparkles")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.gold)
                }

                VStack(spacing: 10) {
                    Button(action: onPlayAgain) {
                        Text(L10n.t(.playAgain, lang))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.accentGradient, in: Capsule())
                    }
                    Button(action: onMenu) {
                        Text(L10n.t(.backToMenu, lang))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.cream.opacity(0.85))
                            .padding(.vertical, 6)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(26)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Theme.charcoal.opacity(0.92))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.4), radius: 24, y: 10)
            .padding(24)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) { appeared = true }
        }
    }

    private func stat(icon: String, value: String, label: String, record: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: record ? "crown.fill" : icon)
                .font(.caption)
                .foregroundStyle(record ? AnyShapeStyle(Theme.gold) : AnyShapeStyle(Theme.accentGradient))
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.cream)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.cream.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(record ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Suit symbols and paper confetti tumbling down the screen, drawn in a single Canvas.
private struct SuitConfetti: View {
    private struct Particle {
        let x: Double, speed: Double, sway: Double, swaySpeed: Double
        let spin: Double, size: Double, phase: Double, symbol: Int, color: Color
    }

    private static let palette: [Color] = [Theme.ember, Theme.scorched, Theme.gold, Theme.cream, Theme.cardRed]

    private let particles: [Particle] = {
        var seed: UInt64 = 42
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(1 << 53)
        }
        return (0..<70).map { i in
            Particle(
                x: next(), speed: 0.12 + next() * 0.16, sway: 10 + next() * 26, swaySpeed: 1 + next() * 2,
                spin: (next() - 0.5) * 6, size: 10 + next() * 14, phase: next(),
                symbol: i % 6, color: palette[Int(next() * Double(palette.count)) % palette.count]
            )
        }
    }()

    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in particles {
                    let progress = (t * p.speed + p.phase).truncatingRemainder(dividingBy: 1)
                    let y = -40 + progress * (size.height + 80)
                    let x = p.x * size.width + sin(t * p.swaySpeed + p.phase * 6) * p.sway
                    var ctx = context
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(t * p.spin + p.phase * 6))
                    if p.symbol < 4, let symbol = ctx.resolveSymbol(id: p.symbol) {
                        ctx.draw(symbol, in: CGRect(x: -p.size / 2, y: -p.size / 2, width: p.size, height: p.size))
                    } else {
                        let rect = CGRect(x: -p.size * 0.3, y: -p.size * 0.15, width: p.size * 0.6, height: p.size * 0.3)
                        ctx.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(p.color))
                    }
                }
            } symbols: {
                ForEach(0..<4, id: \.self) { i in
                    Image(systemName: Suit.allCases[i].symbolName)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(i < 2 ? Theme.ember : Theme.cream)
                        .frame(width: 24, height: 24)
                        .tag(i)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
