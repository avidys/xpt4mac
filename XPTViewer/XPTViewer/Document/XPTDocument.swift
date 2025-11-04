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

    var failureReason: String? {
        switch self {
        case .emptyFile:
            return "The file does not contain any bytes to parse."
        case .invalidFormat:
            return "The binary structure did not match the SAS Version 5 transport layout."
        case .unsupported(let message):
            return message
        case .readOnly:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyFile:
            return "Verify that the exported .xpt file is not zero bytes before opening it."
        case .invalidFormat:
            return "Confirm that the file was created as a SAS XPORT Version 5 transport file (for example with SAS PROC COPY or PROC CPORT). Sample datasets are available from the CDISC/Pharmaverse libraries and the tidyverse documentation."
        case .unsupported:
            return "Try exporting the dataset again using a SAS XPORT Version 5 compatible tool."
        case .readOnly:
            return "Use SAS or another XPT writer to save changes to a new file."
        }
    }
}
