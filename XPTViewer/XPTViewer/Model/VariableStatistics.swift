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
    }

    let variable: XPTVariable
    let total: Int
    let observed: Int
    let missing: Int
    let uniqueCount: Int
    let categories: [CategoryCount]
    let numericSummary: NumericSummary?

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

        if variable.type == .numeric {
            let numericValues = nonNilValues.compactMap { Double($0) }
            if !numericValues.isEmpty {
                numericSummary = VariableStatistics.numericSummary(values: numericValues, missing: missing)
            } else {
                numericSummary = nil
            }
        } else {
            numericSummary = nil
        }

        categories = VariableStatistics.categoryCounts(values: nonNilValues, total: total)
    }
}

private extension VariableStatistics {
    static func categoryCounts(values: [String], total: Int) -> [CategoryCount] {
        guard !values.isEmpty else { return [] }
        var counter: [String: Int] = [:]
        for value in values {
            counter[value, default: 0] += 1
        }
        return counter
            .map { key, value in
                CategoryCount(value: key, count: value, percentage: total == 0 ? 0 : Double(value) / Double(total))
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

        return NumericSummary(count: count, missing: missing, min: minValue, max: maxValue, mean: meanValue, median: medianValue, q1: q1Value, q3: q3Value, standardDeviation: stdValue, density: densityPoints)
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
}
