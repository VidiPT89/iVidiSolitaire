import SwiftUI

enum Theme {
    static let ember = Color(red: 1.00, green: 0.42, blue: 0.11)      // laranja vivo
    static let scorched = Color(red: 0.85, green: 0.62, blue: 0.09)   // amarelo queimado
    static let ink = Color(red: 0.06, green: 0.05, blue: 0.05)        // preto quente
    static let charcoal = Color(red: 0.11, green: 0.10, blue: 0.10)
    static let cream = Color(red: 0.98, green: 0.95, blue: 0.90)
    static let cardRed = Color(red: 0.80, green: 0.11, blue: 0.13)
    static let gold = Color(red: 1.00, green: 0.80, blue: 0.30)

    static let gradient = LinearGradient(
        colors: [ink, charcoal, ember.opacity(0.35)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentGradient = LinearGradient(
        colors: [ember, scorched],
        startPoint: .leading,
        endPoint: .trailing
    )
}

/// The table surface behind the cards.
enum TableTheme: String, CaseIterable, Identifiable {
    case ember, felt, ocean, wine

    var id: String { rawValue }

    /// Only the brand theme follows light/dark mode; the felts are always dark cloth.
    func isLight(_ scheme: ColorScheme) -> Bool { self == .ember && scheme == .light }

    func colors(_ scheme: ColorScheme) -> (top: Color, bottom: Color, glow: Color) {
        switch self {
        case .ember where scheme == .light:
            return (Color(red: 0.99, green: 0.93, blue: 0.82), Color(red: 0.96, green: 0.82, blue: 0.60), Theme.ember.opacity(0.10))
        case .ember:
            return (Color(red: 0.13, green: 0.11, blue: 0.10), Theme.ink, Theme.ember.opacity(0.14))
        case .felt:
            return (Color(red: 0.10, green: 0.45, blue: 0.24), Color(red: 0.03, green: 0.24, blue: 0.12), Color(red: 0.40, green: 0.85, blue: 0.45).opacity(0.18))
        case .ocean:
            return (Color(red: 0.08, green: 0.27, blue: 0.47), Color(red: 0.02, green: 0.11, blue: 0.24), Color(red: 0.35, green: 0.70, blue: 1.00).opacity(0.18))
        case .wine:
            return (Color(red: 0.42, green: 0.08, blue: 0.14), Color(red: 0.18, green: 0.02, blue: 0.06), Color(red: 1.00, green: 0.40, blue: 0.45).opacity(0.15))
        }
    }

    func textColor(_ scheme: ColorScheme) -> Color { isLight(scheme) ? Theme.ink : Theme.cream }
}

/// Felt-like table surface: a soft gradient, a pool of light in the middle, fine cloth grain
/// and a vignette towards the edges.
struct TableBackground: View, Equatable {
    let theme: TableTheme
    let scheme: ColorScheme

    var body: some View {
        let colors = theme.colors(scheme)
        GeometryReader { geo in
            let radius = max(geo.size.width, geo.size.height) * 0.75
            ZStack {
                LinearGradient(colors: [colors.top, colors.bottom], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [colors.glow, .clear], center: UnitPoint(x: 0.5, y: 0.35), startRadius: 0, endRadius: radius)
                FeltGrain(light: theme.isLight(scheme))
                RadialGradient(
                    colors: [.clear, .black.opacity(theme.isLight(scheme) ? 0.06 : 0.35)],
                    center: .center,
                    startRadius: radius * 0.45,
                    endRadius: radius * 1.1
                )
            }
        }
        .ignoresSafeArea()
    }
}

/// Thousands of tiny specks with a fixed seed, rendered once into a flat layer.
private struct FeltGrain: View {
    let light: Bool

    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func next() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double(seed >> 11) / Double(1 << 53)
            }
            let count = Int(size.width * size.height / 90)
            for _ in 0..<count {
                let rect = CGRect(x: next() * size.width, y: next() * size.height, width: 1.1, height: 1.1)
                let bright = next() > 0.5
                let color: Color = bright ? .white : .black
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(light ? 0.035 : (bright ? 0.035 : 0.10))))
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

/// Colour schemes for the back of the cards.
enum CardBackStyle: String, CaseIterable, Identifiable {
    case ember, crimson, navy, emerald, onyx

    var id: String { rawValue }

    var colors: (Color, Color) {
        switch self {
        case .ember: return (Theme.ember, Theme.scorched)
        case .crimson: return (Color(red: 0.72, green: 0.07, blue: 0.12), Color(red: 0.45, green: 0.02, blue: 0.08))
        case .navy: return (Color(red: 0.14, green: 0.30, blue: 0.62), Color(red: 0.05, green: 0.12, blue: 0.32))
        case .emerald: return (Color(red: 0.06, green: 0.55, blue: 0.38), Color(red: 0.02, green: 0.28, blue: 0.20))
        case .onyx: return (Color(red: 0.24, green: 0.23, blue: 0.24), Color(red: 0.07, green: 0.07, blue: 0.08))
        }
    }

    var ornament: Color {
        self == .onyx ? Theme.gold : Theme.cream
    }
}

private struct CardBackStyleKey: EnvironmentKey {
    static let defaultValue: CardBackStyle = .ember
}

extension EnvironmentValues {
    var cardBackStyle: CardBackStyle {
        get { self[CardBackStyleKey.self] }
        set { self[CardBackStyleKey.self] = newValue }
    }
}
