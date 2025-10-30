import SwiftUI

struct DataTableView: View {
    let dataset: XPTDataset

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            Table(dataset.rows) {
                ForEach(dataset.variables) { variable in
                    TableColumn(variable.name) { row in
                        Text(row.displayValue(for: variable))
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(minWidth: minTableWidth, minHeight: minTableHeight)
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var minTableWidth: CGFloat {
        let base = dataset.variables.reduce(CGFloat.zero) { partialResult, variable in
            partialResult + CGFloat(variable.displayWidth)
        }
        return max(base, 400)
    }

    private var minTableHeight: CGFloat {
        max(CGFloat(dataset.rows.count) * 28, 200)
    }
}

private extension XPTDataset.Row {
    func displayValue(for variable: XPTVariable) -> String {
        values[variable.id] ?? ""
    }
}

private extension XPTVariable {
    var displayWidth: Int {
        max(name.count * 14, 120)
    }
}
