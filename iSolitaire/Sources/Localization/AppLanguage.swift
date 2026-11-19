import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Codable {
    case portuguese = "pt"
    case english = "en"

    var displayName: String {
        switch self {
        case .portuguese: return "Português"
        case .english: return "English"
        }
    }

    static func systemDefault() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("pt") ? .portuguese : .english
    }
}

enum AppColorScheme: String, CaseIterable, Codable {
    case system, light, dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// UserDefaults keys shared by the settings screen (through `AppSettingsStore`) and the
/// game's sound/haptics players, which read them directly at play time.
enum AppPreferences {
    static let soundKey = "iSolitaire.soundEnabled"
    static let hapticsKey = "iSolitaire.hapticsEnabled"

    static var soundEnabled: Bool { UserDefaults.standard.object(forKey: soundKey) as? Bool ?? true }
    static var hapticsEnabled: Bool { UserDefaults.standard.object(forKey: hapticsKey) as? Bool ?? true }
}

final class AppSettingsStore: ObservableObject {
    @AppStorage("iSolitaire.language") var languageRaw: String = AppLanguage.systemDefault().rawValue
    @AppStorage("iSolitaire.colorScheme") var colorSchemeRaw: String = AppColorScheme.system.rawValue
    @AppStorage("iSolitaire.tableTheme") var tableThemeRaw: String = TableTheme.ember.rawValue
    @AppStorage("iSolitaire.cardBack") var cardBackRaw: String = CardBackStyle.ember.rawValue
    @AppStorage("iSolitaire.leftHanded") var leftHanded: Bool = false
    @AppStorage(AppPreferences.soundKey) var soundEnabled: Bool = true
    @AppStorage(AppPreferences.hapticsKey) var hapticsEnabled: Bool = true

    var language: AppLanguage {
        get { AppLanguage(rawValue: languageRaw) ?? .english }
        set { languageRaw = newValue.rawValue }
    }

    var colorScheme: AppColorScheme {
        get { AppColorScheme(rawValue: colorSchemeRaw) ?? .system }
        set { colorSchemeRaw = newValue.rawValue }
    }

    var tableTheme: TableTheme {
        get { TableTheme(rawValue: tableThemeRaw) ?? .ember }
        set { tableThemeRaw = newValue.rawValue }
    }

    var cardBack: CardBackStyle {
        get { CardBackStyle(rawValue: cardBackRaw) ?? .ember }
        set { cardBackRaw = newValue.rawValue }
    }
}
