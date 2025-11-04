import SwiftUI

struct ContentView: View {
    @Binding var document: XPTDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            if let dataset = document.dataset {
                DataTableView(dataset: dataset)
            } else if let error = document.lastError {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Unable to open file")
                        .font(.title3)
                        .bold()
                    Text(error.localizedDescription)
                        .font(.callout)
                    if let localized = error as? LocalizedError {
                        if let failureReason = localized.failureReason {
                            Text(failureReason)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let suggestion = localized.recoverySuggestion {
                            Text(suggestion)
                                .font(.footnote)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Need a known-good SAS XPORT (V5) file?")
                            .font(.subheadline)
                            .bold()
                        Text("Try downloading one of the public examples below or exporting a dataset with SAS PROC COPY/CPORT:")
                            .font(.footnote)
                        Link("Tidyverse Haven documentation", destination: URL(string: "https://haven.tidyverse.org/reference/read_xpt.html")!)
                        Link("Python xport reference implementation", destination: URL(string: "https://github.com/selik/xport")!)
                        Link("CDISC ADaM ADSL example dataset", destination: URL(string: "https://pharmaverse.github.io/examples/adam/adsl")!)
                    }
                    .font(.footnote)
                }
                .padding()
            } else {
                VStack(alignment: .center, spacing: 12) {
                    ProgressView()
                    Text("Loading…")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(document.displayTitle)
                .font(.title)
                .bold()
            if let dataset = document.dataset {
                HStack(spacing: 16) {
                    if let created = dataset.createdDate {
                        Label("Created: \(created.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar")
                    }
                    if let modified = dataset.modifiedDate {
                        Label("Modified: \(modified.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar.badge.clock")
                    }
                    Label("Variables: \(dataset.variables.count)", systemImage: "square.grid.3x1.folder")
                    Label("Observations: \(dataset.rows.count)", systemImage: "tablecells")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else {
                Text("No dataset available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ContentView(document: .constant(XPTDocument(dataset: XPTDataset.preview())))
        .frame(width: 800, height: 600)
}
