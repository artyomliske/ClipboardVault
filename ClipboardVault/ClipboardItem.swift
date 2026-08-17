import Foundation

enum ClipboardContentKind: String, Codable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: ClipboardContentKind
    var text: String?
    var imageFileName: String?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var contentDigest: String?
    var createdAt: Date
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        text: String,
        createdAt: Date = .now,
        isPinned: Bool = false
    ) {
        self.id = id
        self.kind = .text
        self.text = text
        self.imageFileName = nil
        self.pixelWidth = nil
        self.pixelHeight = nil
        self.contentDigest = nil
        self.createdAt = createdAt
        self.isPinned = isPinned
    }

    init(
        id: UUID = UUID(),
        imageFileName: String,
        pixelWidth: Int,
        pixelHeight: Int,
        contentDigest: String,
        createdAt: Date = .now,
        isPinned: Bool = false
    ) {
        self.id = id
        self.kind = .image
        self.text = nil
        self.imageFileName = imageFileName
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.contentDigest = contentDigest
        self.createdAt = createdAt
        self.isPinned = isPinned
    }

    var isImage: Bool { kind == .image }

    var preview: String {
        if isImage {
            let width = pixelWidth ?? 0
            let height = pixelHeight ?? 0
            return "Изображение • \(width) × \(height)"
        }
        return (text ?? "")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, text, imageFileName, pixelWidth, pixelHeight
        case contentDigest, createdAt, isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        pixelWidth = try container.decodeIfPresent(Int.self, forKey: .pixelWidth)
        pixelHeight = try container.decodeIfPresent(Int.self, forKey: .pixelHeight)
        contentDigest = try container.decodeIfPresent(String.self, forKey: .contentDigest)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        kind = try container.decodeIfPresent(ClipboardContentKind.self, forKey: .kind)
            ?? (imageFileName == nil ? .text : .image)
    }
}
