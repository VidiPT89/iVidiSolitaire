import SwiftUI

struct MenuView: View {
    @EnvironmentObject var appSettings: AppSettingsStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSettings = false
    @State private var showStats = false
    @State private var hasResumableGame = false
    @State private var standaloneSettings = GameStateStore.loadSettings() ?? GameSettings()
    @State private var fanned = false

    private var lang: AppLanguage { appSettings.language }
    private var theme: TableTheme { appSettings.tableTheme }
    private var textColor: Color { theme.textColor(colorScheme) }

    var body: some View {
        NavigationStack {
            ZStack {
                TableBackground(theme: theme, scheme: colorScheme).equatable()

                VStack(spacing: 22) {
                    Spacer()

                    AppLogo(size: 230)
                        .scaleEffect(fanned ? 1 : 0.92)
                        .opacity(fanned ? 1 : 0.6)

                    Spacer()

                    VStack(spacing: 12) {
                        if hasResumableGame {
                            NavigationLink(value: Route.board(startFresh: false)) {
                                menuButton(L10n.t(.continueGame, lang), icon: "play.fill", primary: true)
                            }
                        }
                        NavigationLink(value: Route.board(startFresh: true)) {
                            menuButton(L10n.t(.newGame, lang), icon: "plus.rectangle.on.rectangle", primary: !hasResumableGame)
                        }
                        NavigationLink(value: Route.academy) {
                            academyButton
                        }
                        HStack(spacing: 12) {
                            Button { showStats = true } label: {
                                menuButton(L10n.t(.stats, lang), icon: "chart.bar.fill", primary: false)
                            }
                            Button { showSettings = true } label: {
                                menuButton(L10n.t(.settings, lang), icon: "gearshape.fill", primary: false)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 28)

                    Spacer()

                    VStack(spacing: 4) {
                        Text(L10n.t(.developedBy, lang)).font(.caption.weight(.semibold))
                        HStack(spacing: 12) {
                            Link("ividi.dev", destination: URL(string: "https://ividi.dev/")!)
                            Link("github.com/VidiPT89", destination: URL(string: "https://github.com/VidiPT89/")!)
                        }
                        .font(.caption2)
                    }
                    .foregroundStyle(textColor.opacity(0.7))
                    .tint(theme.isLight(colorScheme) ? Theme.ember : Theme.gold)
                    .padding(.bottom, 20)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .board(let startFresh):
                    BoardView(startFresh: startFresh)
                case .academy:
                    AcademyView()
                }
            }
            .onAppear {
                hasResumableGame = GameStateStore.loadState().map { !$0.isWon && $0.moves > 0 } ?? false
                standaloneSettings = GameStateStore.loadSettings() ?? GameSettings()
                withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) { fanned = true }
                GameCenter.shared.isMenuVisible = true
            }
            .onDisappear {
                fanned = false
                GameCenter.shared.isMenuVisible = false
            }
            .onChange(of: showSettings || showStats) { _, covered in GameCenter.shared.isMenuCovered = covered }
            .sheet(isPresented: $showSettings) {
                SettingsView(gameSettings: $standaloneSettings).environmentObject(appSettings)
            }
            .sheet(isPresented: $showStats) {
                StatsView().environmentObject(appSettings)
            }
            .onChange(of: standaloneSettings) { _, newValue in
                GameStateStore.saveSettings(newValue)
            }
        }
        .tint(Theme.ember)
    }

    private var academyButton: some View {
        let done = AcademyProgress.completedLessons()
        return HStack(spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .font(.title3)
                .foregroundStyle(Theme.accentGradient)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t(.academy, lang)).font(.headline)
                Text(L10n.format(.lessonsDone, lang, done, Academy.lessons.count))
                    .font(.caption)
                    .opacity(0.7)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).opacity(0.5)
        }
        .foregroundStyle(textColor)
        .padding(.vertical, 12)
        .padding(.horizontal, 18)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.ember.opacity(0.45), lineWidth: 1))
        .contentShape(Rectangle())
    }

    private func menuButton(_ title: String, icon: String, primary: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(title).font(.headline)
            if primary { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity, alignment: primary ? .leading : .center)
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .foregroundStyle(primary ? .white : textColor)
        .background {
            if primary {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.accentGradient)
                    .shadow(color: Theme.ember.opacity(0.35), radius: 10, y: 4)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial)
            }
        }
        .contentShape(Rectangle())
    }
}

private enum Route: Hashable {
    case board(startFresh: Bool)
    case academy
}
