import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @Binding var document: XPTDocument
    @State private var exportError: ExportError?
    @State private var showColumnLabels = true
    @State private var selectedTheme: TableThemeOption = .auto

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            if let dataset = document.dataset {
                DataTableView(dataset: dataset, showColumnLabels: $showColumnLabels, theme: selectedTheme.tableTheme)
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
        .preferredColorScheme(selectedTheme.colorScheme)
        .alert(item: $exportError) { error in
            Alert(title: Text("Export failed"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let dataset = document.dataset {
                HStack(spacing: 16) {
                    if let created = dataset.createdDate {
                        Text("Created: \(created.formatted(date: .abbreviated, time: .shortened))")
                    }
                    if let modified = dataset.modifiedDate {
                        Text("Modified: \(modified.formatted(date: .abbreviated, time: .shortened))")
                    }
                    Text("Variables: \(dataset.variables.count)")
                    Text("Rows: \(dataset.rows.count)")
                    Toggle(isOn: $showColumnLabels) {
                        Text("Labels")
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    Picker("Theme", selection: $selectedTheme) {
                        ForEach(TableThemeOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.small)
                    Spacer()
                    exportMenu(for: dataset)
                        .fixedSize()
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

    private func exportMenu(for dataset: XPTDataset) -> some View {
        Menu {
            Button("Export as CSV") {
                export(dataset: dataset, format: .csv)
            }
            Button("Export as Excel (.xlsx)") {
                export(dataset: dataset, format: .xlsx)
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .menuStyle(.borderlessButton)
    }

    private func export(dataset: XPTDataset, format: DatasetExporter.Format) {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [format.contentType]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.nameFieldStringValue = defaultFilename(for: dataset, format: format)
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            do {
                let exporter = DatasetExporter(dataset: dataset)
                let data = try exporter.data(for: format)
                try data.write(to: url)
            } catch {
                exportError = ExportError(message: error.localizedDescription)
            }
        }
        #endif
    }

    private func defaultFilename(for dataset: XPTDataset, format: DatasetExporter.Format) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = dataset.title.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }
        let name = String(sanitized).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let base = name.isEmpty ? "dataset" : name
        return base + "." + format.fileExtension
    }
}

#Preview {
    ContentView(document: .constant(XPTDocument(dataset: XPTDataset.preview())))
        .frame(width: 800, height: 600)
}

private struct ExportError: Identifiable {
    let id = UUID()
    let message: String
}

private enum TableThemeOption: String, CaseIterable, Identifiable {
    case auto
    case light
    case dark
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto:
            return "Auto"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .custom:
            return "Custom"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .auto, .custom:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var tableTheme: DataTableTheme {
        switch self {
        case .custom:
            return .luminous
        case .auto, .light, .dark:
            return .system
        }
    }
}
