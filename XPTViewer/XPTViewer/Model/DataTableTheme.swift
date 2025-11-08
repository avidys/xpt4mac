import SwiftUI
import Combine

/// Application settings that persist between launches
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private enum Keys {
        static let maxColumnLength = "maxColumnLength"
        static let selectedTheme = "selectedTheme"
        static let decimalDigits = "decimalDigits"
        static let showHeaderStatistics = "showHeaderStatistics"
        static let showColumnLabels = "showColumnLabels"
    }
    
    @Published var maxColumnLength: Int {
        didSet {
            defaults.set(maxColumnLength, forKey: Keys.maxColumnLength)
        }
    }
    
    @Published var selectedTheme: TableThemeOption {
        didSet {
            defaults.set(selectedTheme.rawValue, forKey: Keys.selectedTheme)
        }
    }
    
    @Published var decimalDigits: Int {
        didSet {
            defaults.set(decimalDigits, forKey: Keys.decimalDigits)
        }
    }
    
    @Published var showHeaderStatistics: Bool {
        didSet {
            defaults.set(showHeaderStatistics, forKey: Keys.showHeaderStatistics)
        }
    }
    
    @Published var showColumnLabels: Bool {
        didSet {
            defaults.set(showColumnLabels, forKey: Keys.showColumnLabels)
        }
    }
    
    private init() {
        // Load from UserDefaults or use defaults
        self.maxColumnLength = defaults.object(forKey: Keys.maxColumnLength) as? Int ?? 40
        self.selectedTheme = TableThemeOption(rawValue: defaults.string(forKey: Keys.selectedTheme) ?? "auto") ?? .auto
        self.decimalDigits = defaults.object(forKey: Keys.decimalDigits) as? Int ?? 1
        self.showHeaderStatistics = defaults.object(forKey: Keys.showHeaderStatistics) as? Bool ?? true
        self.showColumnLabels = defaults.object(forKey: Keys.showColumnLabels) as? Bool ?? true
    }
}

enum TableThemeOption: String, CaseIterable, Identifiable {
    case auto
    case light
    case dark
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto:
            return "Auto"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .custom:
            return "Custom"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .auto, .custom:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var tableTheme: DataTableTheme {
        switch self {
        case .custom:
            return .luminous
        case .auto, .light, .dark:
            return .system
        }
    }
}

struct DataTableTheme {
    let containerBackground: AnyShapeStyle
    let headerBackground: AnyShapeStyle
    let oddRowBackground: Color
    let evenRowBackground: Color
    let headerTextColor: Color?

    static let system = DataTableTheme(
        containerBackground: AnyShapeStyle(.thinMaterial),
        headerBackground: AnyShapeStyle(.ultraThinMaterial),
        oddRowBackground: Color.accentColor.opacity(0.04),
        evenRowBackground: .clear,
        headerTextColor: nil
    )

    static let luminous = DataTableTheme(
        containerBackground: AnyShapeStyle(Color(red: 0.1, green: 0.25, blue: 0.15)),
        headerBackground: AnyShapeStyle(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.12, green: 0.28, blue: 0.18),
                    Color(red: 0.08, green: 0.22, blue: 0.12)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        oddRowBackground: Color(red: 0.12, green: 0.28, blue: 0.18),
        evenRowBackground: Color(red: 0.1, green: 0.25, blue: 0.15),
        headerTextColor: Color(red: 0.85, green: 0.95, blue: 0.88)
    )
}
