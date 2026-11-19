import SwiftUI

/// The app's logo artwork (the same art as the app icon), used on the splash and the menu.
struct AppLogo: View {
    var size: CGFloat = 220

    var body: some View {
        Image("Logo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
            .accessibilityLabel("iVidiSolitaire")
    }
}
