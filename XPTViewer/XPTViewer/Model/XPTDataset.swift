import Foundation

struct XPTDataset {
    struct Row: Identifiable {
        let id: UUID
        var values: [UUID: String]

        init(id: UUID = UUID(), values: [UUID: String]) {
            self.id = id
            self.values = values
        }
    }

    let title: String
    let createdDate: Date?
    let modifiedDate: Date?
    let variables: [XPTVariable]
    let rows: [Row]

    init(title: String, createdDate: Date?, modifiedDate: Date?, variables: [XPTVariable], rows: [Row]) {
        self.title = title
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.variables = variables
        self.rows = rows
    }
}

struct XPTVariable: Identifiable {
    enum FieldType {
        case numeric
        case character
    }

    let id: UUID
    let name: String
    let label: String
    let type: FieldType
    let length: Int

    init(name: String, label: String, type: FieldType, length: Int, id: UUID = UUID()) {
        self.id = id
        self.name = name
        self.label = label
        self.type = type
        self.length = length
    }
}

extension XPTVariable.FieldType {
    var displayName: String {
        switch self {
        case .numeric:
            return "Numeric"
        case .character:
            return "Character"
        }
    }
}

extension XPTDataset {
    static func preview() -> XPTDataset {
        let variables = [
            XPTVariable(name: "ID", label: "Identifier", type: .numeric, length: 8),
            XPTVariable(name: "NAME", label: "Participant Name", type: .character, length: 12),
            XPTVariable(name: "AGE", label: "Age", type: .numeric, length: 8)
        ]
        let rows = [
            Row(values: [variables[0].id: "1", variables[1].id: "Alice", variables[2].id: "34"]),
            Row(values: [variables[0].id: "2", variables[1].id: "Bob", variables[2].id: "27"])
        ]
        return XPTDataset(title: "Sample", createdDate: Date(), modifiedDate: Date(), variables: variables, rows: rows)
    }
}
