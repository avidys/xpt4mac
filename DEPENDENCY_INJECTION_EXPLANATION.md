# What Does "Add Dependency Injection" Mean?

## Current Situation (Hard Dependencies)

Right now, your code creates dependencies **directly inside** the classes that need them:

### Example 1: XPTParser in XPTDocument

```swift
// XPTDocument.swift - Line 25
init(configuration: ReadConfiguration) throws {
    // ...
    dataset = try XPTParser().parse(data: data, suggestedFilename: configuration.file.filename)
    //          ^^^^^^^^^^^^^^ Hard-coded dependency!
}
```

**Problem:** `XPTDocument` **creates** `XPTParser` itself. You can't:
- Test with a mock parser
- Use a different parser implementation
- Control how the parser is created

### Example 2: DatasetExporter in ContentView

```swift
// ContentView.swift - Line 146
private func export(dataset: XPTDataset, format: DatasetExporter.Format) {
    // ...
    let exporter = DatasetExporter(dataset: dataset)
    //              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Hard-coded dependency!
    let data = try exporter.data(for: format)
}
```

**Problem:** `ContentView` **creates** `DatasetExporter` itself. You can't:
- Test export logic without actually exporting files
- Use a different exporter (e.g., for testing)
- Mock the exporter to test error handling

### Example 3: Static Date Formatters

```swift
// VariableStatistics.swift
static let dateParsers: [DateFormatter] = {
    // Static dependency - can't be replaced
}()

// DateFormatter+XPTParsers.swift
static let xptSupportedParsers: [DateFormatter] = {
    // Static dependency - can't be replaced
}()
```

**Problem:** Static dependencies can't be:
- Replaced for testing
- Configured differently
- Mocked

---

## What is Dependency Injection?

**Dependency Injection (DI)** means **passing dependencies in** instead of **creating them inside**.

### The Three Ways to Inject Dependencies:

1. **Constructor Injection** (Initializer) - Pass in the constructor
2. **Property Injection** - Set a property
3. **Method Injection** - Pass as a parameter

---

## How It Would Work

### Current Code (Hard Dependency):

```swift
struct XPTDocument: FileDocument {
    init(configuration: ReadConfiguration) throws {
        // Creates parser directly - hard to test!
        dataset = try XPTParser().parse(data: data, suggestedFilename: filename)
    }
}
```

### With Dependency Injection:

#### Option 1: Constructor Injection

```swift
struct XPTDocument: FileDocument {
    private let parser: XPTParser
    
    // Inject the parser through the initializer
    init(parser: XPTParser = XPTParser()) {
        self.parser = parser
    }
    
    init(configuration: ReadConfiguration, parser: XPTParser = XPTParser()) throws {
        self.parser = parser
        dataset = try parser.parse(data: data, suggestedFilename: filename)
    }
}
```

**Now you can:**
- Use default parser: `XPTDocument(configuration: config)`
- Use custom parser: `XPTDocument(configuration: config, parser: myParser)`
- Use mock parser for testing: `XPTDocument(configuration: config, parser: MockParser())`

---

## Protocol-Based Design (Better for Testing)

Even better: Use **protocols** so you can swap implementations:

### Step 1: Define Protocol

```swift
protocol XPTParsing {
    func parse(data: Data, suggestedFilename: String?) throws -> XPTDataset
}

// Make XPTParser conform to the protocol
extension XPTParser: XPTParsing {
    // Already implements parse(), so this works automatically
}
```

### Step 2: Inject Protocol Instead of Concrete Type

```swift
struct XPTDocument: FileDocument {
    private let parser: XPTParsing
    
    init(parser: XPTParsing = XPTParser()) {
        self.parser = parser
    }
    
    init(configuration: ReadConfiguration, parser: XPTParsing = XPTParser()) throws {
        self.parser = parser
        dataset = try parser.parse(data: data, suggestedFilename: filename)
    }
}
```

### Step 3: Create Mock for Testing

```swift
// For unit testing
struct MockXPTParser: XPTParsing {
    var shouldThrowError = false
    var mockDataset: XPTDataset?
    
    func parse(data: Data, suggestedFilename: String?) throws -> XPTDataset {
        if shouldThrowError {
            throw XPTError.invalidFormat
        }
        return mockDataset ?? XPTDataset.preview()
    }
}

// Now you can test error handling:
func testDocumentWithInvalidFile() {
    let mockParser = MockXPTParser()
    mockParser.shouldThrowError = true
    
    let document = try? XPTDocument(configuration: config, parser: mockParser)
    XCTAssertNil(document?.dataset)
}
```

---

## Complete Example: Refactored Code

### Before (Hard Dependencies):

```swift
// XPTDocument.swift
init(configuration: ReadConfiguration) throws {
    dataset = try XPTParser().parse(data: data, suggestedFilename: filename)
}

// ContentView.swift
private func export(dataset: XPTDataset, format: DatasetExporter.Format) {
    let exporter = DatasetExporter(dataset: dataset)
    let data = try exporter.data(for: format)
}
```

### After (With Dependency Injection):

```swift
// Protocols
protocol XPTParsing {
    func parse(data: Data, suggestedFilename: String?) throws -> XPTDataset
}

protocol DatasetExporting {
    func data(for format: DatasetExporter.Format) throws -> Data
}

// Make existing classes conform
extension XPTParser: XPTParsing { }
extension DatasetExporter: DatasetExporting { }

// XPTDocument.swift
struct XPTDocument: FileDocument {
    private let parser: XPTParsing
    
    init(parser: XPTParsing = XPTParser()) {
        self.parser = parser
    }
    
    init(configuration: ReadConfiguration, parser: XPTParsing = XPTParser()) throws {
        self.parser = parser
        dataset = try parser.parse(data: data, suggestedFilename: filename)
    }
}

// ContentView.swift
struct ContentView: View {
    private let exporterFactory: (XPTDataset) -> DatasetExporting
    
    init(
        document: Binding<XPTDocument>,
        exporterFactory: @escaping (XPTDataset) -> DatasetExporting = { DatasetExporter(dataset: $0) }
    ) {
        self._document = document
        self.exporterFactory = exporterFactory
    }
    
    private func export(dataset: XPTDataset, format: DatasetExporter.Format) {
        let exporter = exporterFactory(dataset)  // Injected!
        let data = try exporter.data(for: format)
    }
}
```

---

## Benefits of Dependency Injection

### 1. **Testability**

You can test with mocks:

```swift
func testExportErrorHandling() {
    struct FailingExporter: DatasetExporting {
        func data(for format: DatasetExporter.Format) throws -> Data {
            throw DatasetExporter.ExportError.encodingFailed
        }
    }
    
    let exporterFactory: (XPTDataset) -> DatasetExporting = { _ in FailingExporter() }
    let view = ContentView(document: .constant(doc), exporterFactory: exporterFactory)
    
    // Test that error is handled correctly
    view.export(dataset: dataset, format: .csv)
    XCTAssertNotNil(view.exportError)
}
```

### 2. **Flexibility**

You can swap implementations:

```swift
// Use a different parser for special files
let customParser = CustomXPTParser()
let document = XPTDocument(configuration: config, parser: customParser)

// Use a cached exporter
let cachedExporter = CachedDatasetExporter(dataset: dataset)
let view = ContentView(document: binding, exporterFactory: { _ in cachedExporter })
```

### 3. **Control**

You control how dependencies are created:

```swift
// Create parser with custom configuration
let parser = XPTParser()
parser.strictMode = true
let document = XPTDocument(configuration: config, parser: parser)
```

### 4. **Isolation**

Components don't know about each other's internals:

```swift
// XPTDocument doesn't need to know HOW XPTParser works
// It just knows it can call parse()
// This is called "loose coupling"
```

---

## Real-World Example: Testing Export Error

### Without DI (Hard to Test):

```swift
// How do you test that export errors are handled?
// You'd have to create a file that causes an encoding error
// Or modify DatasetExporter to throw errors (bad!)
func testExportError() {
    // Can't easily test this!
    let view = ContentView(document: binding)
    view.export(dataset: dataset, format: .csv)
    // How do we make it fail?
}
```

### With DI (Easy to Test):

```swift
func testExportError() {
    struct FailingExporter: DatasetExporting {
        func data(for format: DatasetExporter.Format) throws -> Data {
            throw DatasetExporter.ExportError.encodingFailed
        }
    }
    
    let exporterFactory: (XPTDataset) -> DatasetExporting = { _ in FailingExporter() }
    let view = ContentView(document: binding, exporterFactory: exporterFactory)
    
    view.export(dataset: dataset, format: .csv)
    
    // Now we can verify error is handled
    XCTAssertNotNil(view.exportError)
    XCTAssertEqual(view.exportError?.message, "Failed to encode CSV data as UTF-8")
}
```

---

## Is This Necessary?

**Short answer: Not critical for this project.**

**Why:**
- Current code works fine
- Dependencies are simple (just 2-3 classes)
- No complex configuration needed
- Manual testing is sufficient for this project size

**When it becomes valuable:**
- If you need comprehensive unit tests
- If you want to support multiple parser implementations
- If you need to mock dependencies for integration tests
- If the codebase grows significantly
- If you need to swap implementations at runtime

---

## Current Status

**Phase 4 is marked as "NOT STARTED"** because:
- It's a **nice-to-have**, not a requirement
- The current hard dependencies are **simple and work well**
- It would require **refactoring** all dependent code
- The **benefits don't outweigh the cost** for this project size
- Manual testing is **sufficient** for the current scope

**Recommendation:** Keep current structure unless you plan to add extensive unit testing or need to swap implementations.

---

## Simple Alternative (If You Just Want Testability)

If you only want to test, you can use a simpler approach without full DI:

```swift
// Make dependencies internal (not private) so tests can access
struct XPTParser {
    internal func parse(...) throws -> XPTDataset {
        // ...
    }
}

// In tests, subclass or extend to override behavior
extension XPTParser {
    static func createForTesting() -> XPTParser {
        // Return configured parser for tests
    }
}
```

This gives you some testability without the full DI infrastructure.

---

## Summary

**Dependency Injection** = Pass dependencies in instead of creating them inside

**Benefits:**
- ✅ Testable (can use mocks)
- ✅ Flexible (can swap implementations)
- ✅ Isolated (loose coupling)

**Cost:**
- ⚠️ More code (protocols, initializers)
- ⚠️ More complexity
- ⚠️ Refactoring required

**For this project:** Not necessary, but would be valuable if you add unit tests.

