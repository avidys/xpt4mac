import SwiftUI

struct DataTableView: View {
    let dataset: XPTDataset
    private let statisticsByVariable: [UUID: VariableStatistics]
    private let tableTheme: DataTableTheme

    @Binding private var showColumnLabels: Bool

    @StateObject private var horizontalScrollState: HorizontalScrollState
    @State private var selectedVariable: XPTVariable?

    private struct ColumnSummary {
        let typeDescription: String
        let missingDescription: String
        let uniqueDescription: String
    }

    init(dataset: XPTDataset, showColumnLabels: Binding<Bool>, theme: DataTableTheme) {
        self.dataset = dataset
        self.tableTheme = theme
        _showColumnLabels = showColumnLabels
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

            horizontalScrollIndicator
                .padding(.horizontal, columnSpacing)
                .padding(.vertical, 4)
        }
        .background(tableTheme.containerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .popover(item: $selectedVariable) { variable in
            NavigationStack {
                VariableStatisticsView(
                    statistics: statisticsByVariable[variable.id]
                        ?? VariableStatistics(variable: variable, values: dataset.values(for: variable))
                )
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

            SynchronizedHorizontalScrollView(state: horizontalScrollState) {
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
        return Button {
            selectedVariable = variable
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(variable.name)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(headerColor(for: .primary) ?? Color.primary)
                if showColumnLabels, !variable.label.isEmpty {
                    Text(variable.label)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(headerColor(for: .secondary) ?? Color.secondary)
                }
                Text("type: \(summary.typeDescription)")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(headerColor(for: .secondary) ?? Color.secondary)
                Text(summary.missingDescription)
                    .font(.caption2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(headerColor(for: .tertiary) ?? Color.secondary.opacity(0.7))
                Text(summary.uniqueDescription)
                    .font(.caption2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(headerColor(for: .tertiary) ?? Color.secondary.opacity(0.7))
            }
            .padding(.trailing, columnSpacing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dataCell(text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.trailing, columnSpacing)
    }

    private func rowBackground(for index: Int) -> Color {
        index.isMultiple(of: 2) ? tableTheme.evenRowBackground : tableTheme.oddRowBackground
    }

    private func columnSummary(for variable: XPTVariable) -> ColumnSummary {
        let statistics = statisticsByVariable[variable.id]
            ?? VariableStatistics(variable: variable, values: dataset.values(for: variable))
        let typeDescription = statistics.detectedType.displayName
        let missingDescription = missingText(from: statistics)
        let uniqueDescription = "unique: \(statistics.uniqueCount.formatted())"

        return ColumnSummary(
            typeDescription: typeDescription,
            missingDescription: missingDescription,
            uniqueDescription: uniqueDescription
        )
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

    private var pinnedVariables: [XPTVariable] { [] }

    private var scrollableVariables: [XPTVariable] {
        dataset.variables
    }

    private func width(for variable: XPTVariable) -> CGFloat {
        CGFloat(variable.displayWidth)
    }

    private var horizontalScrollIndicator: some View {
        SynchronizedHorizontalScrollView(state: horizontalScrollState, showsIndicators: true) {
            Color.clear
                .frame(width: scrollableContentWidth, height: 1)
        }
        .frame(height: 12)
    }

    private var scrollableContentWidth: CGFloat {
        max(scrollableVariables.reduce(0) { $0 + width(for: $1) + columnSpacing }, 1)
    }

    private var rowHeight: CGFloat { 32 }

    private var headerBackground: AnyShapeStyle {
        tableTheme.headerBackground
    }

    private var columnSpacing: CGFloat { 12 }
}

private extension DataTableView {
    enum HeaderTextRole {
        case primary
        case secondary
        case tertiary
    }

    func headerColor(for role: HeaderTextRole) -> Color? {
        guard let base = tableTheme.headerTextColor else { return nil }
        switch role {
        case .primary:
            return base
        case .secondary:
            return base.opacity(0.8)
        case .tertiary:
            return base.opacity(0.65)
        }
    }
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
