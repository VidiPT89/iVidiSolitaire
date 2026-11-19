import SwiftUI

@main
struct iVidiSolitaireApp: App {
    @StateObject private var appSettings = AppSettingsStore()

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(appSettings)
                .preferredColorScheme(appSettings.colorScheme.colorScheme)
                .onAppear { GameCenter.shared.authenticate() }
        }
    }
}
