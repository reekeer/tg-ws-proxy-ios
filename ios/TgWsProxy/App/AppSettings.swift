import SwiftUI
import UIKit
import ObjectiveC

enum LanguageSwitcher {
    static var override: AppLanguage = .current
    static let enBundle: Bundle? = Bundle.main
        .path(forResource: "en", ofType: "lproj")
        .flatMap(Bundle.init(path:))

    static func apply(_ language: AppLanguage) {
        override = language
        let codes: [String]
        switch language {
        case .system:  codes = Locale.preferredLanguages
        case .russian: codes = ["ru"]
        case .english: codes = ["en"]
        }
        UserDefaults.standard.set(codes, forKey: "AppleLanguages")
    }

    static func localized(_ key: String) -> String {
        switch override {
        case .english:
            return enBundle?.localizedString(forKey: key, value: key, table: nil) ?? key
        case .russian:
            return key
        case .system:
            return Bundle.main.localizedString(forKey: key, value: key, table: nil)
        }
    }
}

extension String {
    var tgLoc: String { LanguageSwitcher.localized(self) }
}

enum AppTheme: String, CaseIterable {
    case system, light, dark

    var title: String {
        switch self {
        case .system: "Системная".tgLoc
        case .light: "Светлая".tgLoc
        case .dark: "Тёмная".tgLoc
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case system, russian, english

    var title: String {
        switch self {
        case .system: "Как в системе".tgLoc
        case .russian: "Русский"
        case .english: "English"
        }
    }

    var flag: String {
        switch self {
        case .system: "🌐"
        case .russian: "🇷🇺"
        case .english: "🇬🇧"
        }
    }

    var locale: Locale {
        switch self {
        case .system: .current
        case .russian: Locale(identifier: "ru")
        case .english: Locale(identifier: "en")
        }
    }

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "app.language") ?? "") ?? .system
    }
}

enum AccentChoice: String, CaseIterable {
    case telegram, indigo, green, pink, orange, graphite

    var title: String {
        switch self {
        case .telegram: "Telegram"
        case .indigo: "Индиго".tgLoc
        case .green: "Зелёный".tgLoc
        case .pink: "Розовый".tgLoc
        case .orange: "Оранжевый".tgLoc
        case .graphite: "Графит".tgLoc
        }
    }

    var color: Color {
        switch self {
        case .telegram: Color(red: 0.20, green: 0.56, blue: 0.93)
        case .indigo: Color(red: 0.35, green: 0.34, blue: 0.84)
        case .green: Color(red: 0.18, green: 0.70, blue: 0.44)
        case .pink: Color(red: 0.90, green: 0.30, blue: 0.55)
        case .orange: Color(red: 0.95, green: 0.55, blue: 0.20)
        case .graphite: Color(red: 0.36, green: 0.40, blue: 0.47)
        }
    }

    static var current: AccentChoice {
        AccentChoice(rawValue: UserDefaults.standard.string(forKey: "app.accent") ?? "") ?? .telegram
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let themeKey = "app.theme"
    static let accentKey = "app.accent"

    @Published var theme: AppTheme { didSet { Self.save(theme.rawValue, Self.themeKey) } }
    @Published var language: AppLanguage {
        didSet {
            Self.save(language.rawValue, "app.language")
            LanguageSwitcher.apply(language)
            if oldValue != language {
                restartRequired = true
            }
        }
    }
    @Published var accent: AccentChoice { didSet { Self.save(accent.rawValue, Self.accentKey) } }
    @Published var autoStart: Bool { didSet { Self.save(autoStart, "app.autoStart") } }
    @Published var reconnect: Bool { didSet { Self.save(reconnect, "app.reconnect") } }
    @Published var notifications: Bool { didSet { Self.save(notifications, "app.notifications") } }
    @Published var haptics: Bool { didSet { Self.save(haptics, "app.haptics") } }
    @Published var liquidGlass: Bool { didSet { Self.save(liquidGlass, "app.liquidGlass") } }
    @Published var onboardingDone: Bool { didSet { Self.save(onboardingDone, "app.onboardingDone") } }
    @Published var restartRequired = false
    @Published var restartToken = UUID()

    init() {
        let d = UserDefaults.standard
        theme = AppTheme(rawValue: d.string(forKey: Self.themeKey) ?? "") ?? .system
        language = AppLanguage(rawValue: d.string(forKey: "app.language") ?? "") ?? .system
        accent = AccentChoice(rawValue: d.string(forKey: Self.accentKey) ?? "") ?? .telegram
        autoStart = d.object(forKey: "app.autoStart") as? Bool ?? false
        reconnect = d.object(forKey: "app.reconnect") as? Bool ?? true
        notifications = d.object(forKey: "app.notifications") as? Bool ?? false
        haptics = d.object(forKey: "app.haptics") as? Bool ?? true
        liquidGlass = d.object(forKey: "app.liquidGlass") as? Bool ?? true
        onboardingDone = d.object(forKey: "app.onboardingDone") as? Bool ?? false
        LanguageSwitcher.apply(language)
    }

    func restartInterface() {
        restartRequired = false
        restartToken = UUID()
    }

    private static func save(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }
}

enum Haptics {
    static var enabled: Bool {
        UserDefaults.standard.object(forKey: "app.haptics") as? Bool ?? true
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
