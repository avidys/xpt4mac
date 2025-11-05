import SwiftUI

struct DataTableView: View {
    let dataset: XPTDataset
    private let statisticsByVariable: [UUID: VariableStatistics]

    @StateObject private var horizontalScrollState: HorizontalScrollState
    @State private var selectedVariable: XPTVariable?

    private struct ColumnSummary {
        let typeDescription: String
        let missingDescription: String
        let uniqueDescription: String
    }

    init(dataset: XPTDataset) {
        self.dataset = dataset
        var statistics: [UUID: VariableStatistics] = [:]
        for variable in dataset.variables {
            statistics[variable.id] = VariableStatistics(variable: variable, values: dataset.values(for: variable))
        }
        statisticsByVariable = statistics
        _horizontalScrollState = StateObject(wrappedValue: HorizontalScrollState())
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section(header: headerRow) {
                        ForEach(Array(dataset.rows.enumerated()), id: \.1.id) { index, row in
                            tableRow(index: index, row: row)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .popover(item: $selectedVariable) { variable in
            NavigationStack {
                VariableStatisticsView(statistics: statisticsByVariable[variable.id] ?? VariableStatistics(variable: variable, values: dataset.values(for: variable)))
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(pinnedVariables) { variable in
                headerButton(for: variable)
                    .frame(width: width(for: variable), alignment: .leading)
                    .background(headerBackground)
            }

            SynchronizedHorizontalScrollView(state: horizontalScrollState, showsIndicators: true) {
                HStack(spacing: 0) {
                    ForEach(scrollableVariables) { variable in
                        headerButton(for: variable)
                            .frame(width: width(for: variable), alignment: .leading)
                            .background(headerBackground)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(headerBackground)
        .overlay(Divider(), alignment: .bottom)
    }

    private func tableRow(index: Int, row: XPTDataset.Row) -> some View {
        HStack(spacing: 0) {
            ForEach(pinnedVariables) { variable in
                dataCell(text: row.displayValue(for: variable))
                    .frame(width: width(for: variable), height: rowHeight, alignment: .leading)
                    .background(rowBackground(for: index))
            }

            SynchronizedHorizontalScrollView(state: horizontalScrollState) {
                HStack(spacing: 0) {
                    ForEach(scrollableVariables) { variable in
                        dataCell(text: row.displayValue(for: variable))
                            .frame(width: width(for: variable), height: rowHeight, alignment: .leading)
                            .background(rowBackground(for: index))
                    }
                }
            }
            .frame(height: rowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .overlay(Divider(), alignment: .bottom)
    }

    private func headerButton(for variable: XPTVariable) -> some View {
        let summary = columnSummary(for: variable)
        Button {
            selectedVariable = variable
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(variable.name)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !variable.label.isEmpty {
                    Text(variable.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("type: \(summary.typeDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(summary.missingDescription)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(summary.uniqueDescription)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.trailing, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dataCell(text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.trailing, 12)
    }

    private func rowBackground(for index: Int) -> Color {
        index.isMultiple(of: 2) ? Color.clear : Color.accentColor.opacity(0.04)
    }

    private func columnSummary(for variable: XPTVariable) -> ColumnSummary {
        let statistics = statisticsByVariable[variable.id]
            ?? VariableStatistics(variable: variable, values: dataset.values(for: variable))
        let typeDescription = inferredType(for: variable, statistics: statistics)
        let missingDescription = missingText(from: statistics)
        let uniqueDescription = "unique: \(statistics.uniqueCount.formatted())"

        return ColumnSummary(
            typeDescription: typeDescription,
            missingDescription: missingDescription,
            uniqueDescription: uniqueDescription
        )
    }

    private func inferredType(for variable: XPTVariable, statistics: VariableStatistics) -> String {
        let values = nonEmptyValues(for: variable)
        guard !values.isEmpty else {
            return variable.type == .numeric ? "numeric" : "text"
        }

        if variable.type == .character && values.allSatisfy(isDateString) {
            return "date"
        }

        let numericValues = values.compactMap(Double.init)
        if numericValues.count == values.count {
            let isInteger = numericValues.allSatisfy { $0.isInteger }
            return isInteger ? "integer" : "numeric"
        }

        if variable.type == .numeric {
            return "numeric"
        }

        let uniqueCount = statistics.uniqueCount
        if uniqueCount > 0 {
            let threshold = min(20, max(1, statistics.observed / 2))
            if uniqueCount <= threshold {
                return "factor"
            }
        }

        return "text"
    }

    private func missingText(from statistics: VariableStatistics) -> String {
        let percent = statistics.total == 0 ? 0 : Double(statistics.missing) / Double(statistics.total)
        let formattedPercent = percent.formatted(.percent.precision(.fractionLength(0...1)))
        return "miss: \(statistics.missing.formatted()) (\(formattedPercent))"
    }

    private func nonEmptyValues(for variable: XPTVariable) -> [String] {
        dataset.values(for: variable).compactMap { value in
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
            return trimmed
        }
    }

    private var pinnedVariables: [XPTVariable] {
        dataset.variables.filter(shouldPin)
    }

    private var scrollableVariables: [XPTVariable] {
        dataset.variables.filter { !shouldPin($0) }
    }

    private func shouldPin(_ variable: XPTVariable) -> Bool {
        let uppercase = variable.name.uppercased()
        return uppercase == "USUBJID" || uppercase.hasSuffix("SEQ")
    }

    private func width(for variable: XPTVariable) -> CGFloat {
        CGFloat(variable.displayWidth)
    }

    private var rowHeight: CGFloat { 32 }

    private var headerBackground: some ShapeStyle {
        .ultraThinMaterial
    }
}

private extension DataTableView {
    func isDateString(_ value: String) -> Bool {
        DateFormatter.cachedDateParsers.contains { formatter in
            formatter.date(from: value) != nil
        }
    }
}

private extension Double {
    var isInteger: Bool {
        isFinite && rounded() == self
    }
}

private extension DateFormatter {
    static let cachedDateParsers: [DateFormatter] = {
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
}

private extension XPTDataset.Row {
    func displayValue(for variable: XPTVariable) -> String {
        values[variable.id] ?? ""
    }
}

private extension XPTVariable {
    var displayWidth: Int {
        max(name.count * 14, 140)
    }
}

private extension XPTDataset {
    func values(for variable: XPTVariable) -> [String?] {
        rows.map { row in
            row.values[variable.id]
        }
    }
}
