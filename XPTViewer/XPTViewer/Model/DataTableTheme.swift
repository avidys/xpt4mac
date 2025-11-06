import SwiftUI

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

    static let systemDark = DataTableTheme(
        containerBackground: AnyShapeStyle(Color.white.opacity(0.04)),
        headerBackground: AnyShapeStyle(Color.white.opacity(0.08)),
        oddRowBackground: Color.white.opacity(0.06),
        evenRowBackground: Color.white.opacity(0.03),
        headerTextColor: Color.white.opacity(0.85)
    )

    static let luminous = DataTableTheme(
        containerBackground: AnyShapeStyle(Color(red: 0.96, green: 0.98, blue: 1.0).opacity(0.6)),
        headerBackground: AnyShapeStyle(
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.95, green: 0.97, blue: 1.0), Color(red: 0.86, green: 0.92, blue: 1.0)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        oddRowBackground: Color(red: 0.92, green: 0.96, blue: 1.0).opacity(0.5),
        evenRowBackground: Color.white.opacity(0.4),
        headerTextColor: Color(red: 0.08, green: 0.18, blue: 0.36)
    )
}
