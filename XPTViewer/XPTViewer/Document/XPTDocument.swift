import SwiftUI
import UniformTypeIdentifiers

struct XPTDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.sasXPT] }

    var dataset: XPTDataset?
    var lastError: Error?

    init() {
        dataset = nil
        lastError = nil
    }

    init(dataset: XPTDataset) {
        self.dataset = dataset
        self.lastError = nil
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw XPTError.emptyFile
        }
        do {
            dataset = try XPTParser().parse(data: data, suggestedFilename: configuration.file.filename)
            lastError = nil
        } catch {
            dataset = nil
            lastError = error
            throw error
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        throw XPTError.readOnly
    }

    var displayTitle: String {
        dataset?.title ?? "SAS Transport File"
    }
}

enum XPTError: LocalizedError {
    case emptyFile
    case invalidFormat
    case unsupported(String)
    case readOnly

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The selected file is empty."
        case .invalidFormat:
            return "The file is not a valid SAS transport (XPT) file."
        case .unsupported(let message):
            return message
        case .readOnly:
            return "Saving XPT files is not supported."
        }
    }
}
