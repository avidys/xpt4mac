import Foundation

extension DateFormatter {
    /// Legacy property for backward compatibility
    /// Use XPTDateParsing.parsers instead
    static let xptSupportedParsers: [DateFormatter] = XPTDateParsing.parsers

    /// Parses a date string using XPT date formatters
    /// - Parameter value: The date string to parse
    /// - Returns: A parsed Date if successful, nil otherwise
    static func parseXPTDate(from value: String) -> Date? {
        XPTDateParsing.parse(value)
    }
}
