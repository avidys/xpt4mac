import Foundation

struct XPTParser {
    private struct NameStringRecord {
        let type: Int
        let length: Int
        let name: String
        let label: String
        let format: String
        let position: Int
    }

    func parse(data: Data, suggestedFilename: String?) throws -> XPTDataset {
        guard data.count >= 80 else {
            throw XPTError.invalidFormat
        }

        guard let namestrHeaderRange = data.range(of: Data("HEADER RECORD*******NAMESTR HEADER RECORD!!!!!!!".utf8)),
              let obsHeaderRange = data.range(of: Data("HEADER RECORD*******OBS     HEADER RECORD!!!!!!!".utf8)) else {
            throw XPTError.invalidFormat
        }

        let nameStrBlockStart = alignToRecordBoundary(index: namestrHeaderRange.upperBound)
        let nameStrBlockEnd = obsHeaderRange.lowerBound
        if nameStrBlockEnd <= nameStrBlockStart {
            throw XPTError.invalidFormat
        }

        let nameStringBlock = data[nameStrBlockStart..<nameStrBlockEnd]

        let nameStringRecordLength = 140

        guard nameStringBlock.count >= nameStringRecordLength else {
            throw XPTError.invalidFormat
        }

        let recordCount = nameStringBlock.count / nameStringRecordLength
        if recordCount == 0 {
            throw XPTError.unsupported("The file does not include variable metadata.")
        }

        var nameRecords: [NameStringRecord] = []
        nameRecords.reserveCapacity(recordCount)

        for index in 0..<recordCount {
            let start = nameStringBlock.startIndex.advanced(by: index * nameStringRecordLength)
            let end = start.advanced(by: nameStringRecordLength)
            guard end <= nameStringBlock.endIndex else { continue }
            let block = nameStringBlock[start..<end]
            if let record = parseNameString(block) {
                nameRecords.append(record)
            }
        }

        if nameRecords.isEmpty {
            throw XPTError.unsupported("Variable descriptors could not be parsed.")
        }

        let datasetTitle = inferDatasetTitle(from: data, fallback: suggestedFilename)
        let createdDate = inferDate(from: data, marker: "DATECREATED")
        let modifiedDate = inferDate(from: data, marker: "DATEMODIFIED")

        let orderedRecords = nameRecords.enumerated().sorted { lhs, rhs in
            let lhsOrder = lhs.element.position > 0 ? lhs.element.position : lhs.offset + 1
            let rhsOrder = rhs.element.position > 0 ? rhs.element.position : rhs.offset + 1
            if lhsOrder == rhsOrder {
                return lhs.offset < rhs.offset
            }
            return lhsOrder < rhsOrder
        }.map { $0.element }

        let variables: [XPTVariable] = orderedRecords.enumerated().map { index, record in
            let baseName = record.name.isEmpty ? "VAR\(index + 1)" : record.name
            let label = record.label.isEmpty ? baseName : record.label
            return XPTVariable(
                name: baseName,
                label: label,
                type: record.type == 1 ? .numeric : .character,
                length: max(record.length, record.type == 1 ? 8 : 1)
            )
        }

        let obsDataStart = alignToRecordBoundary(index: obsHeaderRange.upperBound)
        let rawObservationBytes = Data(data[obsDataStart...])

        let storageWidth = variables.reduce(0) { $0 + $1.length }
        guard storageWidth > 0 else {
            throw XPTError.unsupported("Variables have zero length.")
        }

        let rowWidthCandidates = [storageWidth, Int(ceil(Double(storageWidth) / 8.0)) * 8]

        var resolvedRowWidth: Int?
        var observationBytes = rawObservationBytes

        for candidate in rowWidthCandidates {
            let remainder = rawObservationBytes.count % candidate
            if remainder == 0 {
                resolvedRowWidth = candidate
                break
            }

            if remainder > 0 {
                let fillerStart = rawObservationBytes.index(rawObservationBytes.endIndex, offsetBy: -remainder)
                let fillerRange = fillerStart..<rawObservationBytes.endIndex
                let fillerBytes = rawObservationBytes[fillerRange]
                if fillerBytes.allSatisfy({ $0 == 0x00 || $0 == 0x20 }) {
                    resolvedRowWidth = candidate
                    observationBytes = Data(rawObservationBytes[..<fillerStart])
                    break
                }
            }
        }

        guard let rowWidth = resolvedRowWidth, observationBytes.count >= rowWidth else {
            throw XPTError.unsupported("Unable to determine observation width.")
        }

        let observationCount = observationBytes.count / rowWidth
        var rows: [XPTDataset.Row] = []
        rows.reserveCapacity(observationCount)

        var offset = observationBytes.startIndex
        for _ in 0..<observationCount {
            guard offset < observationBytes.endIndex else { break }
            var rowValues: [UUID: String] = [:]
            rowValues.reserveCapacity(variables.count)
            var rowComplete = true

            for variable in variables {
                guard let cellRange = observationBytes.safeRange(start: offset, length: variable.length) else {
                    offset = observationBytes.endIndex
                    rowComplete = false
                    break
                }
                let cellData = observationBytes[cellRange]
                let value = parseCell(data: cellData, for: variable)
                rowValues[variable.id] = value
                offset = cellRange.upperBound
            }

            if rowComplete {
                rows.append(XPTDataset.Row(values: rowValues))
            }

            let filler = rowWidth - storageWidth
            if filler > 0 {
                offset = observationBytes.index(offset, offsetBy: filler, limitedBy: observationBytes.endIndex) ?? observationBytes.endIndex
            }
        }

        return XPTDataset(
            title: datasetTitle,
            createdDate: createdDate,
            modifiedDate: modifiedDate,
            variables: variables,
            rows: rows
        )
    }

    private func parseNameString(_ data: Data) -> NameStringRecord? {
        guard data.count >= 140 else { return nil }

        let type = Int(data.bigEndianInt16(at: 0))
        let length = Int(data.bigEndianInt16(at: 4))
        let order = Int(data.bigEndianInt16(at: 6))
        let name = data.asciiString(at: 8, length: 8)
        let label = data.asciiString(at: 16, length: 40)
        let format = data.asciiString(at: 56, length: 8)

        return NameStringRecord(type: type, length: length, name: name, label: label, format: format, position: order)
    }

    private func parseCell(data: Data, for variable: XPTVariable) -> String {
        switch variable.type {
        case .character:
            return data.asciiString().trimmingCharacters(in: .whitespacesAndNewlines)
        case .numeric:
            return parseNumericValue(data)
        }
    }

    private func parseNumericValue(_ data: Data) -> String {
        guard data.count >= 8 else {
            return ""
        }
        let bytes = data[data.startIndex..<data.startIndex + 8]
        if bytes.allSatisfy({ $0 == 0 }) {
            return "0"
        }
        if bytes.first == 0x2E { // missing value
            return ""
        }
        let sign = (bytes[bytes.startIndex] & 0x80) != 0
        let exponent = Int(bytes[bytes.startIndex] & 0x7F) - 64
        var fraction: UInt64 = 0
        for byte in bytes.dropFirst() {
            fraction = (fraction << 8) | UInt64(byte)
        }
        if fraction == 0 {
            return sign ? "-0" : "0"
        }
        var value = Double(fraction) / Double(1 << 56)
        value *= pow(16.0, Double(exponent))
        if sign {
            value *= -1
        }
        if value.isFinite {
            return Self.numberFormatter.string(from: NSNumber(value: value)) ?? String(value)
        } else {
            return ""
        }
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private func inferDatasetTitle(from data: Data, fallback: String?) -> String {
        if let memberRange = data.range(of: Data("MEMBER  NAME".utf8)) {
            let start = memberRange.upperBound
            let limit = min(start + 80, data.count)
            let slice = data[start..<limit]
            let text = String(data: slice, encoding: .ascii) ?? ""
            let components = text.split(whereSeparator: { $0 == " " || $0 == "\0" })
            if let name = components.first, !name.isEmpty {
                return name.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if let fallback, !fallback.isEmpty {
            return (fallback as NSString).deletingPathExtension
        }
        return "XPT Dataset"
    }

    private func inferDate(from data: Data, marker: String) -> Date? {
        guard let range = data.range(of: Data(marker.utf8)) else { return nil }
        let start = range.upperBound
        let limit = min(start + 32, data.count)
        let slice = data[start..<limit]
        let text = (String(data: slice, encoding: .ascii) ?? "").trimmingCharacters(in: .whitespaces)
        let formatter = DateFormatter()
        formatter.dateFormat = "ddMMMyy:HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: text)
    }

    private func alignToRecordBoundary(index: Int) -> Int {
        let recordSize = 80
        let remainder = index % recordSize
        if remainder == 0 {
            return index
        }
        return index + (recordSize - remainder)
    }
}

private extension Data {
    func asciiString(at offset: Int, length: Int) -> String {
        guard offset >= 0, length > 0, count >= offset + length else { return "" }
        let rangeStart = index(startIndex, offsetBy: offset)
        let rangeEnd = index(rangeStart, offsetBy: length)
        let slice = self[rangeStart..<rangeEnd]
        return String(bytes: slice, encoding: .ascii)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func asciiString() -> String {
        String(bytes: self, encoding: .ascii) ?? ""
    }

    func bigEndianInt16(at offset: Int) -> Int16 {
        guard offset >= 0, count >= offset + 2 else { return 0 }
        let start = index(startIndex, offsetBy: offset)
        return Int16(bitPattern: UInt16(self[start]) << 8 | UInt16(self[index(after: start)]))
    }

    func bigEndianInt32(at offset: Int) -> Int32 {
        guard offset >= 0, count >= offset + 4 else { return 0 }
        let start = index(startIndex, offsetBy: offset)
        var value: UInt32 = 0
        for i in 0..<4 {
            let byte = self[index(start, offsetBy: i)]
            value = (value << 8) | UInt32(byte)
        }
        return Int32(bitPattern: value)
    }

    func safeRange(start: Int, length: Int) -> Range<Int>? {
        guard length >= 0 else { return nil }
        let end = start + length
        guard start >= 0, end <= count else { return nil }
        return start..<end
    }
}
