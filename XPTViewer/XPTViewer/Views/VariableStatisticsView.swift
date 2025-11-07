import SwiftUI
import Charts
#if os(macOS)
import AppKit
#endif

struct VariableStatisticsView: View {
    let statistics: VariableStatistics
    @State private var showCopyConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                attributesSection
                summarySection
                detailSections
            }
            .padding()
        }
        .frame(minWidth: 420, minHeight: 400)
        .navigationTitle(statistics.variable.name)
        .toolbar {
            ToolbarItem(placement: .status) {
                if showCopyConfirmation {
                    Label("Copied", systemImage: "checkmark")
                        .font(.footnote)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    copyToClipboard()
                } label: {
                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                }
            }
        }
    }

    private var attributesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Column attributes")
                .font(.headline)
            Grid(horizontalSpacing: 24, verticalSpacing: 12) {
                GridRow {
                    summaryItem(title: "Name", value: statistics.variable.name)
                    summaryItem(title: "Label", value: statistics.variable.label.isEmpty ? "—" : statistics.variable.label)
                    summaryItem(title: "SAS Type", value: statistics.variable.type.displayName)
                }
                GridRow {
                    summaryItem(title: "Detected Type", value: statistics.detectedType.displayName)
                    summaryItem(title: "Length", value: statistics.variable.length.formatted())
                        .gridCellColumns(2)
                }
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overview")
                .font(.headline)
            Grid(horizontalSpacing: 24, verticalSpacing: 12) {
                GridRow {
                    summaryItem(title: "Total", value: statistics.total.formatted())
                    summaryItem(title: "Observed", value: statistics.observed.formatted())
                    summaryItem(title: "Missing", value: statistics.missing.formatted())
                }
                GridRow {
                    summaryItem(title: "Unique", value: statistics.uniqueCount.formatted())
                    summaryItem(title: "Observed %", value: observedPercent)
                    summaryItem(title: "Missing %", value: missingPercent)
                }
            }
        }
    }

    @ViewBuilder
    private var detailSections: some View {
        switch statistics.detectedType {
        case .numeric:
            if let numeric = statistics.numericSummary {
                numericSection(summary: numeric)
            } else {
                Text("No numeric summary available.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .factor:
            factorSection
        case .date, .dateTime:
            if let dateSummary = statistics.dateSummary {
                dateSection(summary: dateSummary)
            }
        case .text:
            textSection
        }
    }

    private var missingPercent: String {
        let percentage = statistics.total == 0 ? 0 : Double(statistics.missing) / Double(statistics.total)
        return percentage.formatted(.percent.precision(.fractionLength(0...1)))
    }

    private var observedPercent: String {
        let percentage = statistics.total == 0 ? 0 : Double(statistics.observed) / Double(statistics.total)
        return percentage.formatted(.percent.precision(.fractionLength(0...1)))
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

            if !summary.histogram.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Histogram")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Chart(summary.histogram) { bin in
                        BarMark(
                            xStart: .value("Start", bin.lowerBound),
                            xEnd: .value("End", bin.upperBound),
                            y: .value("Count", bin.count)
                        )
                        .foregroundStyle(Color.accentColor.opacity(0.7))
                    }
                    .frame(height: 180)
                }
            }

            if !summary.density.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Density (KDE)")
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

    private var factorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Factor levels")
                .font(.headline)
            if statistics.categories.isEmpty {
                Text("No categories available.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
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
    }

    private func dateSection(summary: VariableStatistics.DateSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(statistics.detectedType == .dateTime ? "Date & time summary" : "Date summary")
                .font(.headline)
            let formatter = Date.FormatStyle(
                date: .abbreviated,
                time: statistics.detectedType == .dateTime ? .shortened : .omitted
            )
            Grid(horizontalSpacing: 24, verticalSpacing: 12) {
                GridRow {
                    summaryItem(title: "Start", value: summary.min.formatted(formatter))
                    summaryItem(title: "End", value: summary.max.formatted(formatter))
                    summaryItem(title: "Median", value: summary.median.formatted(formatter))
                }
                GridRow {
                    summaryItem(title: "Mean days", value: summary.meanDays.formatted(.number.precision(.fractionLength(0...2))))
                    summaryItem(title: "Std. Dev days", value: summary.standardDeviationDays.formatted(.number.precision(.fractionLength(0...2))))
                    summaryItem(title: "Median days", value: summary.medianDays.formatted(.number.precision(.fractionLength(0...2))))
                }
                GridRow {
                    summaryItem(title: "Q1 days", value: summary.q1Days.formatted(.number.precision(.fractionLength(0...2))))
                    summaryItem(title: "Q3 days", value: summary.q3Days.formatted(.number.precision(.fractionLength(0...2))))
                    summaryItem(title: "Max days", value: summary.maxDays.formatted(.number.precision(.fractionLength(0...2))))
                }
            }

            if !summary.timeline.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Timeline")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Chart(summary.timeline) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Count", point.count)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.accentColor.opacity(0.25))

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Count", point.count)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.accentColor)
                    }
                    .frame(height: 200)
                }
            }
        }
    }

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text summary")
                .font(.headline)
            Text("No additional statistics are available for free-form text columns.")
                .font(.callout)
                .foregroundStyle(.secondary)
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

    private func copyToClipboard() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(statistics.clipboardSummary, forType: .string)
        showCopyConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopyConfirmation = false
        }
        #endif
    }
}

