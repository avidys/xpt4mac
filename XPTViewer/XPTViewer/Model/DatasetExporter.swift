import Foundation
import UniformTypeIdentifiers

struct DatasetExporter {
    enum Format {
        case csv
        case xlsx

        var fileExtension: String {
            switch self {
            case .csv:
                return "csv"
            case .xlsx:
                return "xlsx"
            }
        }

        var contentType: UTType {
            switch self {
            case .csv:
                return .commaSeparatedText
            case .xlsx:
                return UTType(filenameExtension: "xlsx") ?? .data
            }
        }

    }

    let dataset: XPTDataset

    func data(for format: Format) throws -> Data {
        switch format {
        case .csv:
            return csvData()
        case .xlsx:
            return try xlsxData()
        }
    }
}

private extension DatasetExporter {
    func csvData() -> Data {
        var rows: [String] = []
        let header = (["ROW_ID"] + dataset.variables.map { $0.name }).joined(separator: ",")
        rows.append(header)

        for (index, row) in dataset.rows.enumerated() {
            let rowId = "\(index + 1)"
            let values = dataset.variables.map { variable -> String in
                csvEscaped(row.value(for: variable))
            }
            rows.append(([csvEscaped(rowId)] + values).joined(separator: ","))
        }

        return rows.joined(separator: "\n").data(using: .utf8) ?? Data()
    }

    func csvEscaped(_ value: String) -> String {
        if value.isEmpty { return "" }
        let containsSpecial = value.contains(",") || value.contains("\n") || value.contains("\"")
        if containsSpecial {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    func xlsxData() throws -> Data {
        let entries = try xlsxEntries()
        let builder = ZipArchiveBuilder(entries: entries)
        return builder.build()
    }

    func xlsxEntries() throws -> [ZipEntry] {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let rows = xlsxSheetRows()

        return [
            ZipEntry(path: "[Content_Types].xml", data: xlsxContentTypes()),
            ZipEntry(path: "_rels/.rels", data: xlsxRelationships()),
            ZipEntry(path: "docProps/app.xml", data: xlsxAppProperties()),
            ZipEntry(path: "docProps/core.xml", data: xlsxCoreProperties(created: timestamp)),
            ZipEntry(path: "xl/_rels/workbook.xml.rels", data: xlsxWorkbookRelationships()),
            ZipEntry(path: "xl/workbook.xml", data: xlsxWorkbook()),
            ZipEntry(path: "xl/styles.xml", data: xlsxStyles()),
            ZipEntry(path: "xl/worksheets/sheet1.xml", data: rows)
        ]
    }

    func xlsxContentTypes() -> Data {
        xml("""
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
            <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
            <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
            <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
            <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
        </Types>
        """)
    }

    func xlsxRelationships() -> Data {
        xml("""
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
            <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
            <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
        </Relationships>
        """)
    }

    func xlsxWorkbookRelationships() -> Data {
        xml("""
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
            <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """)
    }

    func xlsxWorkbook() -> Data {
        xml("""
        <?xml version="1.0" encoding="UTF-8"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
            <sheets>
                <sheet name="Dataset" sheetId="1" r:id="rId1"/>
            </sheets>
        </workbook>
        """)
    }

    func xlsxStyles() -> Data {
        xml("""
        <?xml version="1.0" encoding="UTF-8"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <fonts count="1">
                <font>
                    <sz val="11"/>
                    <name val="Menlo"/>
                </font>
            </fonts>
            <fills count="1">
                <fill>
                    <patternFill patternType="none"/>
                </fill>
            </fills>
            <borders count="1">
                <border/>
            </borders>
            <cellStyleXfs count="1">
                <xf/>
            </cellStyleXfs>
            <cellXfs count="1">
                <xf xfId="0"/>
            </cellXfs>
        </styleSheet>
        """)
    }

    func xlsxAppProperties() -> Data {
        xml("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
            <Application>XPTViewer</Application>
            <AppVersion>1.0</AppVersion>
        </Properties>
        """)
    }

    func xlsxCoreProperties(created: String) -> Data {
        let title = dataset.title.xmlEscaped()
        return xml("""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <dc:title>\(title)</dc:title>
            <dc:creator>XPTViewer</dc:creator>
            <cp:lastModifiedBy>XPTViewer</cp:lastModifiedBy>
            <dcterms:created xsi:type="dcterms:W3CDTF">\(created)</dcterms:created>
            <dcterms:modified xsi:type="dcterms:W3CDTF">\(created)</dcterms:modified>
        </cp:coreProperties>
        """)
    }

    func xlsxSheetRows() -> Data {
        var rows: [String] = []
        let allVariables = dataset.variables
        let headers = ["Row ID"] + allVariables.map { $0.name }
        rows.append(xlsxRow(index: 1, values: headers.map { .string($0) }))

        for (rowIndex, row) in dataset.rows.enumerated() {
            var values: [XLSXCellValue] = [.string("\(rowIndex + 1)")]
            for variable in allVariables {
                let raw = row.value(for: variable)
                if variable.type == .numeric, let number = Double(raw) {
                    values.append(.number(number))
                } else {
                    values.append(.string(raw))
                }
            }
            rows.append(xlsxRow(index: rowIndex + 2, values: values))
        }

        let joined = rows.joined(separator: "")
        return xml("""
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>
                \(joined)
            </sheetData>
        </worksheet>
        """)
    }

    enum XLSXCellValue {
        case string(String)
        case number(Double)
    }

    func xlsxRow(index: Int, values: [XLSXCellValue]) -> String {
        var cells: [String] = []
        for (columnIndex, value) in values.enumerated() {
            let reference = "\(columnName(for: columnIndex))\(index)"
            switch value {
            case .string(let stringValue):
                let escaped = stringValue.xmlEscaped()
                cells.append("<c r=\"\(reference)\" t=\"inlineStr\"><is><t>\(escaped)</t></is></c>")
            case .number(let number):
                cells.append("<c r=\"\(reference)\"><v>\(number)</v></c>")
            }
        }
        return "<row r=\"\(index)\">\(cells.joined())</row>"
    }

    func columnName(for index: Int) -> String {
        var index = index
        var name = ""
        repeat {
            let remainder = index % 26
            name = String(UnicodeScalar(65 + remainder)!) + name
            index = index / 26 - 1
        } while index >= 0
        return name
    }

    func xml(_ string: String) -> Data {
        let lines = string.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let joined = lines.joined(separator: "\n")
        return joined.data(using: .utf8) ?? Data()
    }
}

private struct ZipEntry {
    let path: String
    let data: Data
}

private struct ZipArchiveBuilder {
    let entries: [ZipEntry]

    func build() -> Data {
        var result = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0
        let timestamp = Date()
        let dosTimeDate = msdosDateTime(from: timestamp)

        for entry in entries {
            let fileNameData = entry.path.data(using: .utf8) ?? Data()
            let crc = CRC32.checksum(data: entry.data)
            let size = UInt32(entry.data.count)

            var localHeader = Data()
            localHeader.append(uint32: 0x04034B50)
            localHeader.append(uint16: 20)
            localHeader.append(uint16: 0)
            localHeader.append(uint16: 0)
            localHeader.append(uint16: dosTimeDate.time)
            localHeader.append(uint16: dosTimeDate.date)
            localHeader.append(uint32: crc)
            localHeader.append(uint32: size)
            localHeader.append(uint32: size)
            localHeader.append(uint16: UInt16(fileNameData.count))
            localHeader.append(uint16: 0)

            result.append(localHeader)
            result.append(fileNameData)
            result.append(entry.data)

            var centralHeader = Data()
            centralHeader.append(uint32: 0x02014B50)
            centralHeader.append(uint16: 20)
            centralHeader.append(uint16: 20)
            centralHeader.append(uint16: 0)
            centralHeader.append(uint16: 0)
            centralHeader.append(uint16: dosTimeDate.time)
            centralHeader.append(uint16: dosTimeDate.date)
            centralHeader.append(uint32: crc)
            centralHeader.append(uint32: size)
            centralHeader.append(uint32: size)
            centralHeader.append(uint16: UInt16(fileNameData.count))
            centralHeader.append(uint16: 0)
            centralHeader.append(uint16: 0)
            centralHeader.append(uint16: 0)
            centralHeader.append(uint16: 0)
            centralHeader.append(uint32: 0)
            centralHeader.append(uint32: offset)
            centralHeader.append(fileNameData)

            centralDirectory.append(centralHeader)

            offset += UInt32(localHeader.count + fileNameData.count) + size
        }

        let centralDirectoryOffset = offset
        result.append(centralDirectory)

        var endOfCentralDirectory = Data()
        endOfCentralDirectory.append(uint32: 0x06054B50)
        endOfCentralDirectory.append(uint16: 0)
        endOfCentralDirectory.append(uint16: 0)
        endOfCentralDirectory.append(uint16: UInt16(entries.count))
        endOfCentralDirectory.append(uint16: UInt16(entries.count))
        endOfCentralDirectory.append(uint32: UInt32(centralDirectory.count))
        endOfCentralDirectory.append(uint32: centralDirectoryOffset)
        endOfCentralDirectory.append(uint16: 0)

        result.append(endOfCentralDirectory)
        return result
    }

    private func msdosDateTime(from date: Date) -> (time: UInt16, date: UInt16) {
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = UInt16(max((components.year ?? 1980) - 1980, 0))
        let month = UInt16(components.month ?? 1)
        let day = UInt16(components.day ?? 1)
        let hour = UInt16(components.hour ?? 0)
        let minute = UInt16(components.minute ?? 0)
        let second = UInt16((components.second ?? 0) / 2)

        let dosTime = (hour << 11) | (minute << 5) | second
        let dosDate = (year << 9) | (month << 5) | day
        return (UInt16(dosTime), UInt16(dosDate))
    }
}

private struct CRC32 {
    static let table: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
            return crc
        }
    }()

    static func checksum(data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ table[index]
        }
        return crc ^ 0xFFFFFFFF
    }
}

private extension Data {
    mutating func append(uint16 value: UInt16) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { buffer in
            append(buffer.bindMemory(to: UInt8.self))
        }
    }

    mutating func append(uint32 value: UInt32) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { buffer in
            append(buffer.bindMemory(to: UInt8.self))
        }
    }
}

private extension String {
    func xmlEscaped() -> String {
        var string = self
        string = string.replacingOccurrences(of: "&", with: "&amp;")
        string = string.replacingOccurrences(of: "<", with: "&lt;")
        string = string.replacingOccurrences(of: ">", with: "&gt;")
        string = string.replacingOccurrences(of: "\"", with: "&quot;")
        string = string.replacingOccurrences(of: "'", with: "&apos;")
        return string
    }
}

private extension XPTDataset.Row {
    func value(for variable: XPTVariable) -> String {
        values[variable.id] ?? ""
    }
}
