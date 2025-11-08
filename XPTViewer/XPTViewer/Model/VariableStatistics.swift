import Foundation

/// Shared date parsing utilities for XPT files
/// Consolidates date formatter logic used across the codebase
enum XPTDateParsing {
    /// Supported date formats for parsing XPT date values
    static let supportedFormats = [
        "yyyy-MM-dd",
        "MM/dd/yyyy",
        "dd/MM/yyyy",
        "dd-MMM-yyyy",
        "yyyyMMdd",
        "MMM d, yyyy"
    ]
    
    /// Configured date formatters for parsing XPT date values
    static let parsers: [DateFormatter] = {
        supportedFormats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
        }
    }()
    
    /// Attempts to parse a date string using all supported XPT date formats
    /// - Parameter value: The date string to parse
    /// - Returns: A parsed Date if successful, nil otherwise
    static func parse(_ value: String) -> Date? {
        for formatter in parsers {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }
}

struct VariableStatistics {
    struct CategoryCount: Identifiable {
        let value: String
        let count: Int
        let percentage: Double

        var id: String { value }
    }

    struct DensityPoint: Identifiable {
        let x: Double
        let y: Double

        var id: Double { x }
    }

    struct HistogramBin: Identifiable {
        let lowerBound: Double
        let upperBound: Double
        let count: Int

        var id: Double { lowerBound }
        var midPoint: Double { (lowerBound + upperBound) / 2 }
    }

    struct NumericSummary {
        let count: Int
        let missing: Int
        let min: Double
        let max: Double
        let mean: Double
        let median: Double
        let q1: Double
        let q3: Double
        let standardDeviation: Double
        let density: [DensityPoint]
        let histogram: [HistogramBin]
    }

    struct DateSummary {
        struct TimelinePoint: Identifiable {
            let date: Date
            let count: Int

            var id: Date { date }
        }

        let count: Int
        let missing: Int
        let min: Date
        let max: Date
        let median: Date
        let q1: Date
        let q3: Date
        let minDays: Double
        let q1Days: Double
        let medianDays: Double
        let q3Days: Double
        let maxDays: Double
        let meanDays: Double
        let standardDeviationDays: Double
        let timeline: [TimelinePoint]
    }

    enum DetectedType {
        case numeric(isInteger: Bool)
        case factor
        case date
        case text

        var displayName: String {
            switch self {
            case .numeric(let isInteger):
                return isInteger ? "Integer" : "Real"
            case .factor:
                return "Factor"
            case .date:
                return "Date"
            case .text:
                return "Text"
            }
        }
    }

    let variable: XPTVariable
    let total: Int
    let observed: Int
    let missing: Int
    let uniqueCount: Int
    let detectedType: DetectedType
    let categories: [CategoryCount]
    let numericSummary: NumericSummary?
    let dateSummary: DateSummary?

    init(variable: XPTVariable, values: [String?]) {
        self.variable = variable
        total = values.count

        let cleanedValues = values.map { value -> String? in
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
            return trimmed
        }

        observed = cleanedValues.compactMap { $0 }.count
        missing = total - observed

        let nonNilValues = cleanedValues.compactMap { $0 }
        uniqueCount = Set(nonNilValues).count

        detectedType = VariableStatistics.detectedType(for: variable, values: nonNilValues, total: total, observed: observed)

        switch detectedType {
        case .numeric(let isInteger):
            let numericValues = nonNilValues.compactMap { Double($0) }
            if !numericValues.isEmpty {
                numericSummary = VariableStatistics.numericSummary(values: numericValues, missing: missing)
            } else {
                numericSummary = nil
            }
            dateSummary = nil
            
            // If integer with 11 or fewer unique values from 0 to n, also provide factor statistics
            if isInteger && uniqueCount <= 11 {
                // Check if values are consecutive from 0 to n
                let integerValues = nonNilValues.compactMap { value -> Int? in
                    guard let doubleValue = Double(value) else { return nil }
                    let intValue = Int(doubleValue)
                    // Verify it's actually an integer (no fractional part)
                    return doubleValue == Double(intValue) ? intValue : nil
                }
                
                // Check if we have the same number of unique integer values
                let uniqueIntegers = Set(integerValues)
                if uniqueIntegers.count == uniqueCount && !uniqueIntegers.isEmpty {
                    let sortedUniqueValues = uniqueIntegers.sorted()
                    let minValue = sortedUniqueValues.first!
                    let maxValue = sortedUniqueValues.last!
                    
                    // Check if values are consecutive from 0 to n
                    // Verify: starts at 0, has the right count, and values match 0...maxValue
                    if minValue == 0 && sortedUniqueValues.count == maxValue + 1 {
                        // Verify each value equals its position (0, 1, 2, ..., maxValue)
                        var isConsecutive = true
                        for (index, value) in sortedUniqueValues.enumerated() {
                            if value != index {
                                isConsecutive = false
                                break
                            }
                        }
                        
                        if isConsecutive {
                            // Also calculate categories for factor statistics
                            categories = VariableStatistics.categoryCounts(values: nonNilValues, observed: observed)
                        } else {
                            categories = []
                        }
                    } else {
                        categories = []
                    }
                } else {
                    categories = []
                }
            } else {
                categories = []
            }
        case .factor:
            numericSummary = nil
            dateSummary = nil
            categories = VariableStatistics.categoryCounts(values: nonNilValues, observed: observed)
        case .date:
            let parsedDates = nonNilValues.compactMap { VariableStatistics.parseDate(from: $0) }
            if !parsedDates.isEmpty {
                dateSummary = VariableStatistics.dateSummary(dates: parsedDates, missing: missing)
            } else {
                dateSummary = nil
            }
            numericSummary = nil
            categories = []
        case .text:
            // For text columns, calculate statistics based on string lengths
            let textLengths = nonNilValues.map { Double($0.count) }
            if !textLengths.isEmpty {
                numericSummary = VariableStatistics.numericSummary(values: textLengths, missing: missing)
            } else {
                numericSummary = nil
            }
            dateSummary = nil
            categories = []
        }
    }
}

extension VariableStatistics {
    var clipboardSummary: String {
        let settings = AppSettings.shared
        let precision = 0...settings.decimalDigits
        
        var lines: [String] = []
        lines.append("Variable: \(variable.name)")
        lines.append("Label: \(variable.label.isEmpty ? "—" : variable.label)")
        lines.append("SAS Type: \(variable.type.displayName)")
        lines.append("Detected Type: \(detectedType.displayName)")
        lines.append("Length: \(variable.length)")
        lines.append("")
        lines.append("Total: \(total)")
        lines.append("Observed: \(observed)")
        lines.append("Missing: \(missing)")
        lines.append("Unique: \(uniqueCount)")

        switch detectedType {
        case .numeric:
            if let numericSummary {
                lines.append("")
                lines.append("Numeric Summary")
                lines.append("  Mean: \(numericSummary.mean.formatted(.number.precision(.fractionLength(precision))))")
                lines.append("  Std Dev: \(numericSummary.standardDeviation.formatted(.number.precision(.fractionLength(precision))))")
                lines.append("  Median: \(numericSummary.median.formatted(.number.precision(.fractionLength(precision))))")
                lines.append("  Q1: \(numericSummary.q1.formatted(.number.precision(.fractionLength(precision))))")
                lines.append("  Q3: \(numericSummary.q3.formatted(.number.precision(.fractionLength(precision))))")
                lines.append("  Min: \(numericSummary.min.formatted(.number.precision(.fractionLength(precision))))")
                lines.append("  Max: \(numericSummary.max.formatted(.number.precision(.fractionLength(precision))))")
            }
        case .factor:
            if !categories.isEmpty {
                lines.append("")
                lines.append("Levels")
                for category in categories {
                    let percent = category.percentage.formatted(.percent.precision(.fractionLength(0...2)))
                    lines.append("  \(category.value): \(category.count) (\(percent))")
                }
            }
        case .date:
            if let dateSummary {
                lines.append("")
                lines.append("Date Summary")
                let formatter = Date.FormatStyle(date: .abbreviated, time: .omitted)
                lines.append("  Start: \(dateSummary.min.formatted(formatter))")
                lines.append("  End: \(dateSummary.max.formatted(formatter))")
                lines.append("  Median: \(dateSummary.median.formatted(formatter))")
                lines.append("  Mean days from start: \(dateSummary.meanDays.formatted(.number.precision(.fractionLength(precision))))")
                lines.append("  Std Dev days: \(dateSummary.standardDeviationDays.formatted(.number.precision(.fractionLength(precision))))")
                lines.append("  Median days from start: \(dateSummary.medianDays.formatted(.number.precision(.fractionLength(precision))))")
                lines.append("  Max days from start: \(dateSummary.maxDays.formatted(.number.precision(.fractionLength(precision))))")
            }
        case .text:
            lines.append("")
            lines.append("No additional statistics available for text variables.")
        }

        return lines.joined(separator: "\n")
    }
}

private extension VariableStatistics {
    /// Parses a date string using the shared XPT date formatters
    static func parseDate(from value: String) -> Date? {
        XPTDateParsing.parse(value)
    }

    /// Detects the semantic type of a variable based on its values using heuristic analysis.
    ///
    /// Type detection follows this priority order:
    /// 1. **Numeric**: If all values can be parsed as numbers
    ///    - Subtype: Integer if all values are whole numbers
    /// 2. **Date/DateTime**: If all values can be parsed as dates using known formats
    ///    - Special case: Columns ending with "DTC" are checked for ISO date-time format first
    /// 3. **Factor**: For character variables:
    ///    - If all values have the same size: type = factor
    ///    - If all values are completed (no missing): type = factor
    ///    - Otherwise: If unique count / total < 0.1 (less than 10% unique): type = factor
    /// 4. **Text**: Free-form text (default for character variables)
    ///    - For character variables with varying sizes, missing values, and ≥ 10% unique: type = text
    ///
    /// Heuristics:
    /// - Factor threshold: min(20, 40% of count) - balances between too many and too few categories
    /// - If SAS type is numeric but values aren't parseable, still returns numeric (may be formatted)
    ///
    /// - Parameters:
    ///   - variable: The variable metadata from XPT file
    ///   - values: Non-empty array of string values to analyze (non-nil, non-empty values only)
    ///   - total: Total number of rows (including missing)
    ///   - observed: Number of non-missing values
    /// - Returns: The detected semantic type with any relevant subtypes
    static func detectedType(for variable: XPTVariable, values: [String], total: Int, observed: Int) -> DetectedType {
        guard !values.isEmpty else {
            return variable.type == .numeric ? .numeric(isInteger: false) : .text
        }

        // Try numeric parsing first - if all values are numeric, it's a numeric variable
        let numericValues = values.compactMap(Double.init)
        if numericValues.count == values.count {
            // Check if all values are integers (whole numbers)
            let isInteger = numericValues.allSatisfy { value in
                value.isFinite && value.rounded() == value
            }
            return .numeric(isInteger: isInteger)
        }

        // Special case: Columns ending with "DTC" should be checked for ISO date-time format first
        let isDTCColumn = variable.name.uppercased().hasSuffix("DTC")
        
        // Try ISO date-time parsing for DTC columns
        if isDTCColumn {
            let isoDateTimeFormatter = DateFormatter()
            isoDateTimeFormatter.locale = Locale(identifier: "en_US_POSIX")
            isoDateTimeFormatter.calendar = Calendar(identifier: .gregorian)
            isoDateTimeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            // ISO 8601 date-time formats: "yyyy-MM-dd'T'HH:mm:ss" or "yyyy-MM-dd'T'HH:mm:ss.SSS"
            let isoFormats = [
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm:ss.SSS",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            ]
            
            var isoDateCount = 0
            for value in values {
                var parsed = false
                for format in isoFormats {
                    isoDateTimeFormatter.dateFormat = format
                    if isoDateTimeFormatter.date(from: value) != nil {
                        parsed = true
                        break
                    }
                }
                if parsed {
                    isoDateCount += 1
                }
            }
            
            if isoDateCount == values.count {
                return .date
            }
        }

        // Try date parsing - if all values parse as dates, it's a date variable
        let dateValues = values.compactMap { parseDate(from: $0) }
        if dateValues.count == values.count, !dateValues.isEmpty {
            return .date
        }

        // For character variables, apply enhanced factor detection rules
        if variable.type == .character {
            // Check if most (>80%) non-missing values are numeric
            // If so, consider it text (like IDs, codes, etc.) rather than factor
            let numericCount = values.compactMap(Double.init).count
            let numericRatio = observed > 0 ? Double(numericCount) / Double(observed) : 0.0
            if numericRatio > 0.8 {
                return .text
            }
            
            // Rule 1: If all values have the same size, it's a factor
            let sizes = Set(values.map { $0.count })
            if sizes.count == 1 {
                return .factor
            }
            
            // Rule 2: If all values are completed (no missing), it's a factor
            if observed == total {
                return .factor
            }
            
            // Rule 3: Check unique ratio based on non-missing values
            // If n unique / n not missing < 0.1, it's a factor
            let uniqueCount = Set(values).count
            let uniqueRatio = observed > 0 ? Double(uniqueCount) / Double(observed) : 0.0
            
            // If unique ratio is less than 10% of observed values, it's a factor
            if uniqueRatio < 0.1 {
                return .factor
            }
            
            // Standard factor detection: low cardinality suggests categorical data
            // Threshold: 40% of values, but capped between 1 and 20
            let threshold = max(1, min(20, Int(Double(values.count) * 0.4)))
            if uniqueCount <= threshold {
                return .factor
            }
            
            // Default for character variables with high cardinality: text
            return .text
        }

        // Fallback: use SAS type if numeric, otherwise text
        if variable.type == .numeric {
            return .numeric(isInteger: false)
        }

        return .text
    }

    static func categoryCounts(values: [String], observed: Int) -> [CategoryCount] {
        guard !values.isEmpty else { return [] }
        var counter: [String: Int] = [:]
        for value in values {
            counter[value, default: 0] += 1
        }
        let denominator = max(observed, 1)
        return counter
            .map { key, value in
                CategoryCount(value: key, count: value, percentage: Double(value) / Double(denominator))
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.value < rhs.value
                }
                return lhs.count > rhs.count
            }
    }

    static func numericSummary(values: [Double], missing: Int) -> NumericSummary {
        let sorted = values.sorted()
        let count = sorted.count
        let minValue = sorted.first ?? 0
        let maxValue = sorted.last ?? 0
        let meanValue = sorted.reduce(0, +) / Double(count)
        let medianValue = percentile(sorted, 0.5)
        let q1Value = percentile(sorted, 0.25)
        let q3Value = percentile(sorted, 0.75)
        let stdValue = standardDeviation(values: sorted, mean: meanValue)
        let densityPoints = density(values: sorted)
        let histogramBins = histogram(values: sorted)

        return NumericSummary(
            count: count,
            missing: missing,
            min: minValue,
            max: maxValue,
            mean: meanValue,
            median: medianValue,
            q1: q1Value,
            q3: q3Value,
            standardDeviation: stdValue,
            density: densityPoints,
            histogram: histogramBins
        )
    }

    static func dateSummary(dates: [Date], missing: Int) -> DateSummary {
        let sorted = dates.sorted()
        guard let minDate = sorted.first, let maxDate = sorted.last else {
            return DateSummary(
                count: dates.count,
                missing: missing,
                min: Date(),
                max: Date(),
                median: Date(),
                q1: Date(),
                q3: Date(),
                minDays: 0,
                q1Days: 0,
                medianDays: 0,
                q3Days: 0,
                maxDays: 0,
                meanDays: 0,
                standardDeviationDays: 0,
                timeline: []
            )
        }

        let secondsPerDay: Double = 60 * 60 * 24
        let offsets = sorted.map { $0.timeIntervalSince(minDate) / secondsPerDay }
        let count = offsets.count
        let meanDays = offsets.reduce(0, +) / Double(max(count, 1))
        let medianDays = percentile(offsets, 0.5)
        let q1Days = percentile(offsets, 0.25)
        let q3Days = percentile(offsets, 0.75)
        let maxDays = offsets.last ?? 0
        let stdDays = standardDeviation(values: offsets, mean: meanDays)

        let medianDate = minDate.addingTimeInterval(medianDays * secondsPerDay)
        let q1Date = minDate.addingTimeInterval(q1Days * secondsPerDay)
        let q3Date = minDate.addingTimeInterval(q3Days * secondsPerDay)

        return DateSummary(
            count: count,
            missing: missing,
            min: minDate,
            max: maxDate,
            median: medianDate,
            q1: q1Date,
            q3: q3Date,
            minDays: 0,
            q1Days: q1Days,
            medianDays: medianDays,
            q3Days: q3Days,
            maxDays: maxDays,
            meanDays: meanDays,
            standardDeviationDays: stdDays,
            timeline: timeline(dates: sorted)
        )
    }

    /// Calculates a percentile value using linear interpolation between adjacent values.
    ///
    /// Uses the "nearest rank" method with linear interpolation for non-integer positions.
    /// This matches the behavior of common statistical software (Excel PERCENTILE.INC, R quantile type 7).
    ///
    /// Algorithm:
    /// 1. Calculate position: percentile × (count - 1)
    /// 2. If position is integer, return value at that index
    /// 3. Otherwise, interpolate between floor(position) and ceil(position) using fractional part as weight
    ///
    /// Example for 50th percentile (median) of [1, 2, 3, 4, 5]:
    /// - Position = 0.5 × 4 = 2.0 → returns values[2] = 3
    ///
    /// Example for 25th percentile of [1, 2, 3, 4, 5]:
    /// - Position = 0.25 × 4 = 1.0 → returns values[1] = 2
    ///
    /// Example for 37.5th percentile of [1, 2, 3, 4, 5]:
    /// - Position = 0.375 × 4 = 1.5
    /// - Interpolate between values[1]=2 and values[2]=3 with weight 0.5
    /// - Result = 2 + (3-2) × 0.5 = 2.5
    ///
    /// - Parameters:
    ///   - values: Sorted array of numeric values (must be pre-sorted)
    ///   - percentile: Percentile value between 0.0 and 1.0 (0.5 = median, 0.25 = Q1, 0.75 = Q3)
    /// - Returns: The interpolated percentile value, or NaN if values array is empty
    static func percentile(_ values: [Double], _ percentile: Double) -> Double {
        guard !values.isEmpty else { return .nan }
        
        // Calculate position in the sorted array (0-indexed)
        let position = percentile * Double(values.count - 1)
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))
        
        // If position is exactly on an index, return that value
        if lowerIndex == upperIndex {
            return values[lowerIndex]
        }
        
        // Linear interpolation between adjacent values
        let weight = position - Double(lowerIndex)
        return values[lowerIndex] + (values[upperIndex] - values[lowerIndex]) * weight
    }

    static func standardDeviation(values: [Double], mean: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let variance = values.reduce(0) { partial, value in
            let diff = value - mean
            return partial + diff * diff
        } / Double(values.count)
        return sqrt(variance)
    }

    static func density(values: [Double]) -> [DensityPoint] {
        guard let minValue = values.first, let maxValue = values.last, minValue != maxValue else {
            return []
        }
        let count = values.count
        let bandwidth = optimalBandwidth(values: values)
        let sampleCount = min(max(count * 2, 64), 512)
        let step = (maxValue - minValue) / Double(sampleCount - 1)
        return (0..<sampleCount).map { index in
            let x = minValue + Double(index) * step
            let y = kernelDensity(at: x, values: values, bandwidth: bandwidth)
            return DensityPoint(x: x, y: y)
        }
    }

    /// Creates a histogram by binning numeric values into equal-width intervals.
    ///
    /// Uses the square root rule for bin count: √n bins, with a minimum of 4 bins
    /// and a maximum of 20 bins. This provides a good balance between detail and readability.
    ///
    /// Algorithm:
    /// 1. Calculate bin count: min(20, max(4, √n)) where n is the number of values
    /// 2. Calculate bin width: (max - min) / binCount
    /// 3. Assign each value to a bin based on its position
    /// 4. Handle edge case: values exactly at max go into the last bin
    ///
    /// Bins are left-closed, right-open intervals: [lower, upper)
    /// The last bin is closed on both ends: [lower, upper] to include the maximum value
    ///
    /// - Parameter values: Sorted array of numeric values (must be pre-sorted)
    /// - Returns: Array of histogram bins with bounds and counts, or empty if invalid input
    static func histogram(values: [Double]) -> [HistogramBin] {
        guard let minValue = values.first, let maxValue = values.last, minValue != maxValue else {
            return []
        }
        
        // Square root rule: √n bins provides good balance for most distributions
        // Minimum of 4 bins ensures some detail even for small datasets
        // Maximum of 20 bins to keep histograms readable
        let count = values.count
        let binCount = min(20, max(4, Int(round(sqrt(Double(count))))))
        let width = (maxValue - minValue) / Double(binCount)
        guard width.isFinite, width > 0 else { return [] }

        // Count values in each bin
        var buckets = Array(repeating: 0, count: binCount)
        for value in values {
            var index = Int((value - minValue) / width)
            // Ensure max value goes into last bin (edge case handling)
            if index >= binCount { index = binCount - 1 }
            buckets[index] += 1
        }

        // Create bin objects with proper bounds
        return (0..<binCount).map { index in
            let lower = minValue + Double(index) * width
            // Last bin includes the upper bound to capture max value
            let upper = index == binCount - 1 ? maxValue : lower + width
            return HistogramBin(lowerBound: lower, upperBound: upper, count: buckets[index])
        }
    }

    /// Calculates the optimal bandwidth for kernel density estimation using Silverman's rule of thumb.
    ///
    /// Silverman's rule adapts to the data distribution by using the minimum of:
    /// - Standard deviation (works well for normal distributions)
    /// - Interquartile range / 1.34 (robust to outliers)
    ///
    /// Formula: h = 0.9 × min(σ, IQR/1.34) × n^(-1/5)
    ///
    /// Where:
    /// - h = bandwidth
    /// - σ = standard deviation
    /// - IQR = interquartile range (Q3 - Q1)
    /// - n = sample size
    /// - The 1.34 factor normalizes IQR to match standard deviation for normal distributions
    /// - The n^(-1/5) term makes bandwidth decrease as sample size increases
    ///
    /// This method provides a good default bandwidth that adapts to both the spread
    /// and the sample size of the data, producing smooth density estimates.
    ///
    /// - Parameter values: Sorted array of numeric values (must be pre-sorted for percentile calculation)
    /// - Returns: Optimal bandwidth for KDE, or 1.0 as fallback for edge cases
    static func optimalBandwidth(values: [Double]) -> Double {
        let count = Double(values.count)
        guard count > 1 else { return 1 }
        
        // Calculate standard deviation
        let std = standardDeviation(values: values, mean: values.reduce(0, +) / count)
        
        // Calculate interquartile range (robust measure of spread)
        let q1 = percentile(values, 0.25)
        let q3 = percentile(values, 0.75)
        let iqr = q3 - q1
        
        // Use the smaller of std and normalized IQR (more robust to outliers)
        // The 1.34 factor makes IQR/1.34 ≈ σ for normal distributions
        let scale = min(std, iqr / 1.34)
        if scale <= 0 { return 1 }
        
        // Silverman's rule: 0.9 × scale × n^(-1/5)
        // The n^(-1/5) term ensures bandwidth decreases appropriately with sample size
        return 0.9 * scale * pow(count, -0.2)
    }

    /// Calculates kernel density estimate at point x using Gaussian (normal) kernel.
    ///
    /// Kernel Density Estimation (KDE) is a non-parametric method to estimate the probability
    /// density function of a random variable. This implementation uses the Gaussian kernel,
    /// which places a normal distribution centered at each data point and sums their contributions.
    ///
    /// Formula: f(x) = (1/(n×h)) × Σ K((x - xᵢ)/h)
    ///
    /// Where:
    /// - n = number of data points
    /// - h = bandwidth (controls smoothness)
    /// - K = Gaussian kernel: K(u) = (1/√(2π)) × exp(-u²/2)
    /// - xᵢ = each data point
    ///
    /// The Gaussian kernel gives smooth, continuous density estimates. The bandwidth parameter
    /// controls the trade-off between bias (too smooth) and variance (too jagged):
    /// - Larger bandwidth → smoother estimate, may miss details
    /// - Smaller bandwidth → more detailed, may be noisy
    ///
    /// - Parameters:
    ///   - x: The point at which to estimate the density
    ///   - values: Array of data points (the sample)
    ///   - bandwidth: The smoothing parameter (h), typically from optimalBandwidth()
    /// - Returns: The estimated density at point x, or 0 if bandwidth is invalid
    static func kernelDensity(at x: Double, values: [Double], bandwidth: Double) -> Double {
        guard bandwidth > 0 else { return 0 }
        
        // Normalization coefficient: 1/(n × h × √(2π))
        // This ensures the density integrates to 1 (probability density function property)
        let coefficient = 1.0 / (Double(values.count) * bandwidth * sqrt(2 * .pi))
        
        // Sum contributions from all data points
        // Each point contributes a Gaussian centered at that point, evaluated at x
        let sum = values.reduce(0) { partial, value in
            // Normalize distance by bandwidth: u = (x - xᵢ)/h
            let normalized = (x - value) / bandwidth
            // Gaussian kernel: exp(-u²/2)
            return partial + exp(-0.5 * normalized * normalized)
        }
        
        return coefficient * sum
    }

    static func timeline(dates: [Date]) -> [DateSummary.TimelinePoint] {
        guard !dates.isEmpty else { return [] }
        var counter: [Date: Int] = [:]
        let calendar = Calendar(identifier: .gregorian)
        for date in dates {
            let dayStart = calendar.startOfDay(for: date)
            counter[dayStart, default: 0] += 1
        }
        return counter
            .map { key, value in DateSummary.TimelinePoint(date: key, count: value) }
            .sorted { $0.date < $1.date }
    }
}
