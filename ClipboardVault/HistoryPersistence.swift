import Foundation

struct HistoryPersistence {
    private let fileManager: FileManager
    private let historyURL: URL
    private let imageDirectoryURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let appDirectory = appSupport.appendingPathComponent("ClipboardVault", isDirectory: true)
        self.historyURL = appDirectory.appendingPathComponent("history.json", isDirectory: false)
        self.imageDirectoryURL = appDirectory.appendingPathComponent("Images", isDirectory: true)
    }

    func load() -> [ClipboardItem] {
        guard fileManager.fileExists(atPath: historyURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: historyURL)
            return try Self.decoder.decode([ClipboardItem].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ items: [ClipboardItem]) {
        do {
            try fileManager.createDirectory(
                at: historyURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try Self.encoder.encode(items)
            try data.write(to: historyURL, options: [.atomic])
            removeOrphanedImages(keeping: Set(items.compactMap(\.imageFileName)))
        } catch {
            assertionFailure("Unable to save clipboard history: \(error.localizedDescription)")
        }
    }

    func saveImage(_ data: Data, fileName: String) {
        do {
            try fileManager.createDirectory(at: imageDirectoryURL, withIntermediateDirectories: true)
            try data.write(to: imageDirectoryURL.appendingPathComponent(fileName), options: [.atomic])
        } catch {
            assertionFailure("Unable to save clipboard image: \(error.localizedDescription)")
        }
    }

    func imageData(for fileName: String) -> Data? {
        try? Data(contentsOf: imageDirectoryURL.appendingPathComponent(fileName))
    }

    private func removeOrphanedImages(keeping fileNames: Set<String>) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: imageDirectoryURL,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files where !fileNames.contains(file.lastPathComponent) {
            try? fileManager.removeItem(at: file)
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
