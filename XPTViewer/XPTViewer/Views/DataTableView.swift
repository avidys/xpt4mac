import SwiftUI

struct DataTableView: View {
    let dataset: XPTDataset

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    ForEach(dataset.variables) { variable in
                        Text(variable.name)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                ForEach(dataset.rows) { row in
                    GridRow {
                        ForEach(dataset.variables) { variable in
                            Text(row.displayValue(for: variable))
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(minWidth: minTableWidth, minHeight: minTableHeight, alignment: .topLeading)
            .padding(12)
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
