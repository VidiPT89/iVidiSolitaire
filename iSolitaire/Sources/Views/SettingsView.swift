import SwiftUI

struct SettingsView: View {
    @Binding var gameSettings: GameSettings
    @EnvironmentObject var appSettings: AppSettingsStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var lang: AppLanguage { appSettings.language }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.t(.game, lang)) {
                    Picker(L10n.t(.drawMode, lang), selection: $gameSettings.drawMode) {
                        Text(L10n.t(.drawOne, lang)).tag(DrawMode.drawOne)
                        Text(L10n.t(.drawThree, lang)).tag(DrawMode.drawThree)
                    }
                    Picker(L10n.t(.recycles, lang), selection: $gameSettings.recycleMode) {
                        Text(L10n.t(.unlimited, lang)).tag(RecycleMode.unlimited)
                        Text(L10n.t(.limited, lang)).tag(RecycleMode.limited)
                    }
                    if gameSettings.recycleMode == .limited {
                        Stepper(value: $gameSettings.recycleLimit, in: 1...5) {
                            HStack {
                                Text(L10n.t(.recycleLimit, lang))
                                Spacer()
                                Text("\(gameSettings.recycleLimit)").monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section(L10n.t(.table, lang)) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(TableTheme.allCases) { theme in
                                themeSwatch(theme)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section(L10n.t(.cardBack, lang)) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(CardBackStyle.allCases) { style in
                                Button {
                                    appSettings.cardBack = style
                                } label: {
                                    CardView(card: Card(suit: .spades, rank: .ace), width: 46)
                                        .environment(\.cardBackStyle, style)
                                        .padding(4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 9)
                                                .strokeBorder(Theme.ember, lineWidth: appSettings.cardBack == style ? 2.5 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section {
                    Toggle(L10n.t(.leftHanded, lang), isOn: $appSettings.leftHanded)
                    Toggle(L10n.t(.soundEffects, lang), isOn: $appSettings.soundEnabled)
                    Toggle(L10n.t(.haptics, lang), isOn: $appSettings.hapticsEnabled)
                } header: {
                    Text(L10n.t(.controls, lang))
                } footer: {
                    Text(L10n.t(.controlsFooter, lang))
                }

                Section(L10n.t(.appearance, lang)) {
                    Picker(L10n.t(.appearance, lang), selection: Binding(
                        get: { appSettings.colorScheme },
                        set: { appSettings.colorScheme = $0 }
                    )) {
                        Text(L10n.t(.systemMode, lang)).tag(AppColorScheme.system)
                        Text(L10n.t(.lightMode, lang)).tag(AppColorScheme.light)
                        Text(L10n.t(.darkMode, lang)).tag(AppColorScheme.dark)
                    }
                    .pickerStyle(.segmented)

                    Picker(L10n.t(.language, lang), selection: Binding(
                        get: { appSettings.language },
                        set: { appSettings.language = $0 }
                    )) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                }

                Section(L10n.t(.about, lang)) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t(.developedBy, lang)).font(.footnote.bold())
                        Link(L10n.t(.website, lang), destination: URL(string: "https://ividi.dev/")!)
                            .font(.footnote)
                        Link(L10n.t(.github, lang), destination: URL(string: "https://github.com/VidiPT89/")!)
                            .font(.footnote)
                    }
                    .foregroundStyle(Theme.ember)
                }
            }
            .tint(Theme.ember)
            .navigationTitle(L10n.t(.settings, lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t(.close, lang)) { dismiss() }
                }
            }
        }
    }

    private func themeSwatch(_ theme: TableTheme) -> some View {
        let selected = appSettings.tableTheme == theme
        return Button {
            appSettings.tableTheme = theme
        } label: {
            VStack(spacing: 6) {
                TableBackground(theme: theme, scheme: colorScheme)
                    .frame(width: 72, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(selected ? Theme.ember : Color.primary.opacity(0.15), lineWidth: selected ? 2.5 : 1)
                    )
                    .overlay {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white, Theme.ember)
                        }
                    }
                Text(L10n.themeName(theme, lang))
                    .font(.caption)
                    .foregroundStyle(selected ? Theme.ember : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
