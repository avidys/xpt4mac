import SwiftUI

struct DataTableView: View {
    let dataset: XPTDataset
    private let tableTheme: DataTableTheme
    private let columnMetrics: [UUID: ColumnMetrics]

    @Binding private var showColumnLabels: Bool

    @StateObject private var horizontalScrollState: HorizontalScrollState
    @State private var selectedVariable: XPTVariable?
    @State private var statisticsCache: [UUID: VariableStatistics] = [:]
    @State private var columnSummaries: [UUID: ColumnSummary] = [:]

    private struct ColumnSummary {
        let typeDescription: String
        let missingDescription: String
        let uniqueDescription: String
    }

    private struct ColumnMetrics {
        let width: CGFloat
        let allowsWrapping: Bool
    }

    init(dataset: XPTDataset, showColumnLabels: Binding<Bool>, theme: DataTableTheme) {
        self.dataset = dataset
        self.tableTheme = theme
        _showColumnLabels = showColumnLabels
        var metrics: [UUID: ColumnMetrics] = [:]
        for variable in dataset.variables {
            metrics[variable.id] = DataTableView.metrics(for: variable, in: dataset)
        }
        columnMetrics = metrics
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
                LazyVariableStatisticsView(
                    variable: variable,
                    dataset: dataset,
                    cache: $statisticsCache
                ) { statistics in
                    columnSummaries[variable.id] = ColumnSummary(
                        typeDescription: statistics.detectedType.displayName,
                        missingDescription: DataTableView.missingDescription(from: statistics),
                        uniqueDescription: "unique: \(statistics.uniqueCount.formatted())"
                    )
                }
            }
        }
    }

    private var headerRow: some View {
        headerRowContent
            .background(headerBackgroundFill())
            .overlay(Divider(), alignment: .bottom)
    }

    private var headerRowContent: some View {
        HStack(spacing: 0) {
            ForEach(pinnedVariables) { variable in
                headerButton(for: variable)
                    .frame(width: width(for: variable), alignment: .leading)
                    .background(headerBackgroundFill())
            }

            SynchronizedHorizontalScrollView(state: horizontalScrollState) {
                HStack(spacing: 0) {
                    ForEach(scrollableVariables) { variable in
                        headerButton(for: variable)
                            .frame(width: width(for: variable), alignment: .leading)
                            .background(headerBackgroundFill())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func tableRow(index: Int, row: XPTDataset.Row) -> some View {
        HStack(spacing: 0) {
            ForEach(pinnedVariables) { variable in
                dataCell(text: row.displayValue(for: variable), variable: variable)
                    .frame(width: width(for: variable), alignment: .leading)
                    .frame(minHeight: rowHeight, alignment: .topLeading)
                    .background(rowBackground(for: index))
            }

            SynchronizedHorizontalScrollView(state: horizontalScrollState) {
                HStack(spacing: 0) {
                    ForEach(scrollableVariables) { variable in
                        dataCell(text: row.displayValue(for: variable), variable: variable)
                            .frame(width: width(for: variable), alignment: .leading)
                            .frame(minHeight: rowHeight, alignment: .topLeading)
                            .background(rowBackground(for: index))
                    }
                }
            }
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
                Text("type: \(summary?.typeDescription ?? variable.type.displayName)")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(headerColor(for: .secondary) ?? Color.secondary)
                Text(summary?.missingDescription ?? "miss: —")
                    .font(.caption2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(headerColor(for: .tertiary) ?? Color.secondary.opacity(0.7))
                Text(summary?.uniqueDescription ?? "unique: —")
                    .font(.caption2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(headerColor(for: .tertiary) ?? Color.secondary.opacity(0.7))
            }
            .padding(.trailing, columnSpacing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dataCell(text: String, variable: XPTVariable) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let metrics = columnMetrics[variable.id]
        let allowsWrapping = metrics?.allowsWrapping ?? (trimmed.count > maximumUnwrappedLength)
        return Text(trimmed)
            .font(.system(.body, design: .monospaced))
            .multilineTextAlignment(.leading)
            .lineLimit(allowsWrapping ? nil : 1)
            .truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: allowsWrapping)
            .padding(.trailing, columnSpacing)
    }

    private func rowBackground(for index: Int) -> Color {
        index.isMultiple(of: 2) ? tableTheme.evenRowBackground : tableTheme.oddRowBackground
    }

    private func columnSummary(for variable: XPTVariable) -> ColumnSummary? {
        columnSummaries[variable.id]
    }

    private static func missingDescription(from statistics: VariableStatistics) -> String {
        let percent = statistics.total == 0 ? 0 : Double(statistics.missing) / Double(statistics.total)
        let formattedPercent = percent.formatted(.percent.precision(.fractionLength(0...1)))
        return "miss: \(statistics.missing.formatted()) (\(formattedPercent))"
    }

    private var pinnedVariables: [XPTVariable] { [] }

    private var scrollableVariables: [XPTVariable] {
        dataset.variables
    }

    private func width(for variable: XPTVariable) -> CGFloat {
        columnMetrics[variable.id]?.width ?? 160
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

    private var maximumUnwrappedLength: Int { 80 }

    private func headerBackgroundFill() -> some View {
        Rectangle().fill(headerBackground)
    }
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

private struct LazyVariableStatisticsView: View {
    let variable: XPTVariable
    let dataset: XPTDataset
    @Binding var cache: [UUID: VariableStatistics]
    let onStatisticsComputed: (VariableStatistics) -> Void

    @State private var statistics: VariableStatistics?

    var body: some View {
        Group {
            if let resolvedStatistics = statistics ?? cache[variable.id] {
                VariableStatisticsView(statistics: resolvedStatistics)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Calculating statistics…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 320, minHeight: 200)
                .task {
                    await loadStatistics()
                }
            }
        }
    }

    private func loadStatistics() async {
        if await adoptCachedStatisticsIfNeeded() { return }
        let values = dataset.values(for: variable)
        let computed = VariableStatistics(variable: variable, values: values)
        await MainActor.run {
            cache[variable.id] = computed
            statistics = computed
            onStatisticsComputed(computed)
        }
    }

    @MainActor
    private func adoptCachedStatisticsIfNeeded() -> Bool {
        if let cached = cache[variable.id] {
            statistics = cached
            onStatisticsComputed(cached)
            return true
        }
        if statistics != nil {
            return true
        }
        return false
    }
}

private extension XPTDataset.Row {
    func displayValue(for variable: XPTVariable) -> String {
        values[variable.id] ?? ""
    }
}

private extension XPTDataset {
    func values(for variable: XPTVariable) -> [String?] {
        rows.map { row in
            row.values[variable.id]
        }
    }
}

private extension DataTableView {
    private static func metrics(for variable: XPTVariable, in dataset: XPTDataset) -> ColumnMetrics {
        let values = dataset.values(for: variable).compactMap { value -> String? in
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
            return trimmed
        }
        let maxValueLength = values.map { $0.count }.max() ?? 0
        let headerLength = max(variable.name.count, variable.label.count)
        let minimumCharacters = 12
        let maximumCharacters = 80
        let effectiveCharacters = min(max(max(maxValueLength, headerLength), minimumCharacters), maximumCharacters)
        let allowsWrapping = maxValueLength > maximumCharacters
        let characterWidth: CGFloat = 8.5
        return ColumnMetrics(width: CGFloat(effectiveCharacters) * characterWidth, allowsWrapping: allowsWrapping)
    }
}
