import Foundation

extension DateFormatter {
    static let xptSupportedParsers: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "dd-MMM-yyyy",
            "yyyyMMdd",
            "MMM d, yyyy"
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
        }
    }()

    static func parseXPTDate(from value: String) -> Date? {
        for formatter in xptSupportedParsers {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}
