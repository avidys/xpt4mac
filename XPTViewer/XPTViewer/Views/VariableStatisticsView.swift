import SwiftUI
import Charts

struct VariableStatisticsView: View {
    let statistics: VariableStatistics

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summarySection
                if let numeric = statistics.numericSummary {
                    numericSection(summary: numeric)
                }
                if !statistics.categories.isEmpty {
                    categoricalSection
                }
            }
            .padding()
        }
        .frame(minWidth: 420, minHeight: 400)
        .navigationTitle(statistics.variable.name)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(statistics.variable.label.isEmpty ? statistics.variable.name : statistics.variable.label)
                .font(.title3)
                .bold()
            Grid(horizontalSpacing: 24, verticalSpacing: 12) {
                GridRow {
                    summaryItem(title: "Total", value: statistics.total.formatted())
                    summaryItem(title: "Observed", value: statistics.observed.formatted())
                    summaryItem(title: "Missing", value: statistics.missing.formatted())
                }
                GridRow {
                    summaryItem(title: "Unique", value: statistics.uniqueCount.formatted())
                    summaryItem(title: "Type", value: statistics.variable.type.description)
                    summaryItem(title: "Length", value: statistics.variable.length.formatted())
                }
            }
        }
    }

    private func numericSection(summary: VariableStatistics.NumericSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Numeric summary")
                .font(.headline)
            Grid(horizontalSpacing: 24, verticalSpacing: 12) {
                GridRow {
                    summaryItem(title: "Mean", value: summary.mean.formatted(.number.precision(.fractionLength(0...4))))
                    summaryItem(title: "Std. Dev", value: summary.standardDeviation.formatted(.number.precision(.fractionLength(0...4))))
                    summaryItem(title: "Median", value: summary.median.formatted(.number.precision(.fractionLength(0...4))))
                }
                GridRow {
                    summaryItem(title: "Min", value: summary.min.formatted(.number.precision(.fractionLength(0...4))))
                    summaryItem(title: "Q1", value: summary.q1.formatted(.number.precision(.fractionLength(0...4))))
                    summaryItem(title: "Q3", value: summary.q3.formatted(.number.precision(.fractionLength(0...4))))
                }
                GridRow {
                    summaryItem(title: "Max", value: summary.max.formatted(.number.precision(.fractionLength(0...4))))
                    summaryItem(title: "Observed", value: summary.count.formatted())
                    summaryItem(title: "Missing", value: summary.missing.formatted())
                }
            }

            if !summary.density.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Density")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Chart(summary.density) { point in
                        AreaMark(
                            x: .value("Value", point.x),
                            y: .value("Density", point.y)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.accentColor.opacity(0.25))

                        LineMark(
                            x: .value("Value", point.x),
                            y: .value("Density", point.y)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.accentColor)
                    }
                    .frame(height: 180)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Boxplot")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Chart {
                    RectangleMark(
                        xStart: .value("Q1", summary.q1),
                        xEnd: .value("Q3", summary.q3),
                        yStart: .value("Category", 0),
                        yEnd: .value("Category", 1)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.3))

                    RuleMark(x: .value("Median", summary.median))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .foregroundStyle(Color.accentColor)

                    RuleMark(xStart: .value("Min", summary.min), xEnd: .value("Min", summary.q1))
                        .foregroundStyle(Color.accentColor)

                    RuleMark(xStart: .value("Max", summary.q3), xEnd: .value("Max", summary.max))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(height: 100)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
            }
        }
    }

    private var categoricalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories")
                .font(.headline)
            Grid(horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Value")
                        .font(.subheadline)
                        .bold()
                    Text("Count")
                        .font(.subheadline)
                        .bold()
                    Text("Percent")
                        .font(.subheadline)
                        .bold()
                }
                ForEach(statistics.categories) { category in
                    GridRow {
                        Text(category.value)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(category.count.formatted())
                            .frame(width: 80, alignment: .trailing)
                        Text(category.percentage, format: .percent.precision(.fractionLength(0...2)))
                            .frame(width: 80, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func summaryItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension XPTVariable.FieldType {
    var description: String {
        switch self {
        case .numeric:
            return "Numeric"
        case .character:
            return "Character"
        }
    }
}
