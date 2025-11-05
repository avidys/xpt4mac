import SwiftUI

struct DataTableView: View {
    let dataset: XPTDataset

    @StateObject private var horizontalScrollState = HorizontalScrollState()
    @State private var selectedVariable: XPTVariable?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section(header: headerRow) {
                        ForEach(Array(dataset.rows.enumerated()), id: .element.id) { index, row in
                            tableRow(index: index, row: row)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .sheet(item: $selectedVariable) { variable in
            NavigationStack {
                VariableStatisticsView(statistics: VariableStatistics(variable: variable, values: dataset.values(for: variable)))
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            headerCell(title: "Row", subtitle: "Identifier")
                .frame(width: rowIndexWidth, height: headerHeight, alignment: .leading)
                .background(headerBackground)

            ForEach(pinnedVariables) { variable in
                headerButton(for: variable)
                    .frame(width: width(for: variable), height: headerHeight, alignment: .leading)
                    .background(headerBackground)
            }

            SynchronizedHorizontalScrollView(state: horizontalScrollState, showsIndicators: true) {
                HStack(spacing: 0) {
                    ForEach(scrollableVariables) { variable in
                        headerButton(for: variable)
                            .frame(width: width(for: variable), height: headerHeight, alignment: .leading)
                            .background(headerBackground)
                    }
                }
            }
            .frame(height: headerHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(headerBackground)
        .overlay(Divider(), alignment: .bottom)
    }

    private func tableRow(index: Int, row: XPTDataset.Row) -> some View {
        HStack(spacing: 0) {
            rowIdentifierCell(index: index, row: row)
                .frame(width: rowIndexWidth, height: rowHeight, alignment: .leading)
                .background(rowBackground(for: index))

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

    private func headerCell(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 12)
    }

    private func headerButton(for variable: XPTVariable) -> some View {
        Button {
            selectedVariable = variable
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(variable.name)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(variable.label.isEmpty ? "—" : variable.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(metadata(for: variable))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.trailing, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func rowIdentifierCell(index: Int, row: XPTDataset.Row) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(index + 1)")
                .font(.system(.body, design: .monospaced))
            Text(row.id.uuidString.prefix(8).uppercased())
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 12)
    }

    private func dataCell(text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.trailing, 12)
    }

    private func metadata(for variable: XPTVariable) -> String {
        let typeDescription = variable.type == .numeric ? "Numeric" : "Character"
        return "\(typeDescription) • Length \(variable.length)"
    }

    private func rowBackground(for index: Int) -> Color {
        index.isMultiple(of: 2) ? Color.clear : Color.accentColor.opacity(0.04)
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

    private var rowIndexWidth: CGFloat { 120 }
    private var rowHeight: CGFloat { 32 }
    private var headerHeight: CGFloat { 72 }

    private var headerBackground: some ShapeStyle {
        .ultraThinMaterial
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
