import Foundation

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
                return isInteger ? "Integer" : "Numeric"
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

        detectedType = VariableStatistics.detectedType(for: variable, values: nonNilValues)

        switch detectedType {
        case .numeric:
            let numericValues = nonNilValues.compactMap { Double($0) }
            if !numericValues.isEmpty {
                numericSummary = VariableStatistics.numericSummary(values: numericValues, missing: missing)
            } else {
                numericSummary = nil
            }
            dateSummary = nil
            categories = []
        case .factor:
            numericSummary = nil
            dateSummary = nil
            categories = VariableStatistics.categoryCounts(values: nonNilValues, observed: observed)
        case .date:
            let parsedDates = nonNilValues.compactMap { DateFormatter.parseXPTDate(from: $0) }
            if !parsedDates.isEmpty {
                dateSummary = VariableStatistics.dateSummary(dates: parsedDates, missing: missing)
            } else {
                dateSummary = nil
            }
            numericSummary = nil
            categories = []
        case .text:
            numericSummary = nil
            dateSummary = nil
            categories = []
        }
    }
}

extension VariableStatistics {
    var clipboardSummary: String {
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
                lines.append("  Mean: \(numericSummary.mean.formatted(.number.precision(.fractionLength(0...4))))")
                lines.append("  Std Dev: \(numericSummary.standardDeviation.formatted(.number.precision(.fractionLength(0...4))))")
                lines.append("  Median: \(numericSummary.median.formatted(.number.precision(.fractionLength(0...4))))")
                lines.append("  Q1: \(numericSummary.q1.formatted(.number.precision(.fractionLength(0...4))))")
                lines.append("  Q3: \(numericSummary.q3.formatted(.number.precision(.fractionLength(0...4))))")
                lines.append("  Min: \(numericSummary.min.formatted(.number.precision(.fractionLength(0...4))))")
                lines.append("  Max: \(numericSummary.max.formatted(.number.precision(.fractionLength(0...4))))")
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
                lines.append("  Mean days from start: \(dateSummary.meanDays.formatted(.number.precision(.fractionLength(0...2))))")
                lines.append("  Std Dev days: \(dateSummary.standardDeviationDays.formatted(.number.precision(.fractionLength(0...2))))")
                lines.append("  Median days from start: \(dateSummary.medianDays.formatted(.number.precision(.fractionLength(0...2))))")
                lines.append("  Max days from start: \(dateSummary.maxDays.formatted(.number.precision(.fractionLength(0...2))))")
            }
        case .text:
            lines.append("")
            lines.append("No additional statistics available for text variables.")
        }

        return lines.joined(separator: "\n")
    }
}

private extension VariableStatistics {
    static func detectedType(for variable: XPTVariable, values: [String]) -> DetectedType {
        guard !values.isEmpty else {
            return variable.type == .numeric ? .numeric(isInteger: false) : .text
        }

        let numericValues = values.compactMap(Double.init)
        if numericValues.count == values.count {
            let isInteger = numericValues.allSatisfy { value in
                value.isFinite && value.rounded() == value
            }
            return .numeric(isInteger: isInteger)
        }

        let dateValues = values.compactMap { DateFormatter.parseXPTDate(from: $0) }
        if dateValues.count == values.count, !dateValues.isEmpty {
            return .date
        }

        let uniqueCount = Set(values).count
        let threshold = max(1, min(20, Int(Double(values.count) * 0.4)))
        if uniqueCount <= threshold {
            return .factor
        }

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

    static func percentile(_ values: [Double], _ percentile: Double) -> Double {
        guard !values.isEmpty else { return .nan }
        let position = percentile * Double(values.count - 1)
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))
        if lowerIndex == upperIndex {
            return values[lowerIndex]
        }
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

    static func histogram(values: [Double]) -> [HistogramBin] {
        guard let minValue = values.first, let maxValue = values.last, minValue != maxValue else {
            return []
        }
        let count = values.count
        let binCount = max(4, Int(round(sqrt(Double(count)))))
        let width = (maxValue - minValue) / Double(binCount)
        guard width.isFinite, width > 0 else { return [] }

        var buckets = Array(repeating: 0, count: binCount)
        for value in values {
            var index = Int((value - minValue) / width)
            if index >= binCount { index = binCount - 1 }
            buckets[index] += 1
        }

        return (0..<binCount).map { index in
            let lower = minValue + Double(index) * width
            let upper = index == binCount - 1 ? maxValue : lower + width
            return HistogramBin(lowerBound: lower, upperBound: upper, count: buckets[index])
        }
    }

    static func optimalBandwidth(values: [Double]) -> Double {
        let count = Double(values.count)
        guard count > 1 else { return 1 }
        let std = standardDeviation(values: values, mean: values.reduce(0, +) / count)
        let q1 = percentile(values, 0.25)
        let q3 = percentile(values, 0.75)
        let iqr = q3 - q1
        let scale = min(std, iqr / 1.34)
        if scale <= 0 { return 1 }
        return 0.9 * scale * pow(count, -0.2)
    }

    static func kernelDensity(at x: Double, values: [Double], bandwidth: Double) -> Double {
        guard bandwidth > 0 else { return 0 }
        let coefficient = 1.0 / (Double(values.count) * bandwidth * sqrt(2 * .pi))
        let sum = values.reduce(0) { partial, value in
            let normalized = (x - value) / bandwidth
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
