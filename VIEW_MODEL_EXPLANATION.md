# What Does "Extract View Models" Mean?

## Current Architecture (Without View Models)

Right now, `ContentView` mixes **business logic** with **view code**. For example:

### Current Code Structure:
```swift
struct ContentView: View {
    @Binding var document: XPTDocument
    @State private var exportError: ExportError?
    @State private var showColumnLabels = true
    @State private var selectedTheme: TableThemeOption = .auto
    
    // Business logic mixed in the view:
    private func export(dataset: XPTDataset, format: DatasetExporter.Format) {
        #if os(macOS)
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [format.contentType]
        // ... export logic ...
        #endif
    }
    
    private func defaultFilename(for dataset: XPTDataset, format: DatasetExporter.Format) -> String {
        // ... filename sanitization logic ...
    }
}
```

**Problems:**
- Business logic (export, filename generation) is in the view
- Hard to test the logic separately
- View is doing too much (violates Single Responsibility Principle)
- Can't reuse the logic in other views

---

## What is a View Model?

A **View Model** is a class/struct that:
1. **Holds the state** for a view (like `@State` properties)
2. **Contains business logic** (like export, data transformation)
3. **Publishes changes** using `@Published` or `ObservableObject`
4. **Is testable** independently of the view

### MVVM Pattern:
```
Model (Data) → ViewModel (Logic) → View (UI)
```

---

## Proposed Architecture (With View Models)

### Example: ContentViewModel

```swift
import SwiftUI
import Combine

@MainActor
class ContentViewModel: ObservableObject {
    // State that the view needs
    @Published var showColumnLabels = true
    @Published var selectedTheme: TableThemeOption = .auto
    @Published var exportError: ExportError?
    
    // Business logic methods
    func export(dataset: XPTDataset, format: DatasetExporter.Format) {
        // All the export logic here
        let savePanel = NSSavePanel()
        // ... export implementation ...
    }
    
    func defaultFilename(for dataset: XPTDataset, format: DatasetExporter.Format) -> String {
        // Filename sanitization logic
        // ... implementation ...
    }
    
    // Theme management
    var colorScheme: ColorScheme? {
        selectedTheme.colorScheme
    }
    
    var tableTheme: DataTableTheme {
        selectedTheme.tableTheme
    }
}
```

### Updated ContentView (Simplified)

```swift
struct ContentView: View {
    @Binding var document: XPTDocument
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            if let dataset = document.dataset {
                DataTableView(
                    dataset: dataset, 
                    showColumnLabels: $viewModel.showColumnLabels, 
                    theme: viewModel.tableTheme
                )
            }
            // ... rest of view ...
        }
        .padding()
        .preferredColorScheme(viewModel.colorScheme)
        .alert(item: $viewModel.exportError) { error in
            Alert(title: Text("Export failed"), message: Text(error.message))
        }
    }
    
    private func exportMenu(for dataset: XPTDataset) -> some View {
        Menu {
            Button("Export as CSV") {
                viewModel.export(dataset: dataset, format: .csv)
            }
            // ...
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
    }
}
```

---

## Benefits of View Models

### 1. **Separation of Concerns**
- **View**: Only handles UI layout and presentation
- **ViewModel**: Handles business logic and state management
- **Model**: Represents data structures

### 2. **Testability**
```swift
// You can test the view model without SwiftUI
func testExport() {
    let viewModel = ContentViewModel()
    let dataset = XPTDataset.preview()
    
    // Test export logic
    viewModel.export(dataset: dataset, format: .csv)
    
    // Assert results
    XCTAssertNil(viewModel.exportError)
}
```

### 3. **Reusability**
- Same view model can be used by multiple views
- Logic can be shared across different UI implementations

### 4. **Maintainability**
- Changes to business logic don't require changing view code
- Easier to understand what each component does

### 5. **Dependency Injection**
```swift
class ContentViewModel: ObservableObject {
    private let exporter: DatasetExporterProtocol
    
    init(exporter: DatasetExporterProtocol = DatasetExporter()) {
        self.exporter = exporter
    }
    
    // Now you can inject a mock exporter for testing
}
```

---

## What Would Be Extracted in This Project?

From `ContentView.swift`, these would move to a view model:

1. **Export Logic** (`export()` function)
   - Save panel handling
   - File writing
   - Error handling

2. **Filename Generation** (`defaultFilename()` function)
   - String sanitization
   - Extension handling

3. **Theme Management**
   - Theme selection state
   - Theme-to-color-scheme conversion
   - Theme-to-table-theme conversion

4. **Error State Management**
   - Export error handling
   - Error presentation logic

---

## Is This Necessary?

**Short answer: Not critical for this project.**

**Why:**
- The current code is simple and works well
- The view is not overly complex
- Business logic is minimal
- Testing can be done manually

**When it becomes valuable:**
- If you add more features (undo/redo, multiple file handling, etc.)
- If you need unit tests for the business logic
- If you want to share logic between macOS and iOS versions
- If the view becomes too complex (>500 lines)

---

## Current Status

**Phase 4 is marked as "NOT STARTED"** because:
- It's a **nice-to-have**, not a requirement
- The current architecture is **sufficient** for the app's scope
- It would require **significant refactoring** (8+ hours)
- The **benefits don't outweigh the cost** for this project size

**Recommendation:** Keep the current structure unless you plan to significantly expand the app's functionality.

