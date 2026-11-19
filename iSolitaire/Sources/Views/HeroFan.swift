import SwiftUI

/// The four aces fanned out like a hand of cards, used as the splash and menu artwork.
struct HeroFan: View {
    var cardWidth: CGFloat = 70
    /// 0 = stacked, 1 = fully fanned.
    var spread: CGFloat = 1

    private static let cards: [Card] = [.spades, .hearts, .clubs, .diamonds].map {
        Card(suit: $0, rank: .ace, isFaceUp: true)
    }

    var body: some View {
        ZStack {
            ForEach(Array(Self.cards.enumerated()), id: \.element.id) { index, card in
                let centered = CGFloat(index) - 1.5
                CardView(card: card, width: cardWidth)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 4)
                    .rotationEffect(.degrees(Double(centered * 14 * spread)), anchor: .bottom)
                    .offset(x: centered * cardWidth * 0.32 * spread, y: abs(centered) * 6 * spread)
            }
        }
        .frame(width: cardWidth * 2.6, height: cardWidth * CardMetrics.aspect * 1.15)
        .accessibilityHidden(true)
    }
}
