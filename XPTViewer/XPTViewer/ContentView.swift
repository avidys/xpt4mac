import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @Binding var document: XPTDocument
    @Environment(\.undoManager) var undoManager
    @StateObject private var settings = AppSettings.shared
    @State private var exportError: ExportError?
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Divider()
            if let dataset = document.dataset {
                DataTableView(dataset: dataset, theme: settings.selectedTheme.tableTheme)
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
        .preferredColorScheme(settings.selectedTheme.colorScheme)
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
                .interactiveDismissDisabled(false)
        }
        .alert(item: $exportError) { error in
            Alert(title: Text("Export failed"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            updateWindowTitle()
        }
        .onChange(of: document.dataset?.title) { _ in
            updateWindowTitle()
        }
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openFile()
                } label: {
                    Label("Open", systemImage: "folder")
                }
            }
        }
        #endif
    }
    
    #if os(macOS)
    private func updateWindowTitle() {
        DispatchQueue.main.async {
            // Find the key window or main window
            guard let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow || $0.isMainWindow }) else {
                // If no key window, try to find any window
                guard let window = NSApplication.shared.windows.first else { return }
                updateWindowTitle(for: window)
                return
            }
            updateWindowTitle(for: window)
        }
    }
    
    private func updateWindowTitle(for window: NSWindow) {
        // Use dataset title if available, otherwise use default
        let title = document.dataset?.title ?? "SAS Transport File"
        window.title = title
        // Ensure title is visible and centered (default macOS behavior)
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
    }
    
    private func openFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.sasXPT]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        
        openPanel.begin { response in
            guard response == .OK, let url = openPanel.url else { return }
            // The DocumentGroup should handle opening the file
            // We can trigger it by using NSDocumentController
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { document, documentWasAlreadyOpen, error in
                if let error = error {
                    print("Error opening file: \(error.localizedDescription)")
                }
            }
        }
    }
    #endif

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
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
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
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    HStack {
                        Text("Max Column Length:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Stepper(value: $settings.maxColumnLength, in: 10...100, step: 5) {
                            Text("\(settings.maxColumnLength) characters")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 120, alignment: .trailing)
                        }
                    }
                    
                    Picker("Theme:", selection: $settings.selectedTheme) {
                        ForEach(TableThemeOption.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    
                    Toggle("Show Statistics in Headers", isOn: $settings.showHeaderStatistics)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Toggle("Show Column Labels", isOn: $settings.showColumnLabels)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("Statistics Formatting") {
                    HStack {
                        Text("Decimal Digits:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Stepper(value: $settings.decimalDigits, in: 0...6) {
                            Text("\(settings.decimalDigits) digits")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .trailing)
                        }
                    }
                    Text("Applies to: Mean, Median, Std. Dev, Quartiles")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .frame(width: 400, height: 300)
            .padding()
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}

