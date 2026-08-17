import AppKit
import CryptoKit
import Foundation

enum ClipboardCapture {
    case text(String)
    case image(data: Data, width: Int, height: Int, digest: String)
}

@MainActor
final class PasteboardMonitor {
    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var lastChangeCount: Int
    private let onCapture: (ClipboardCapture) -> Void

    init(
        pasteboard: NSPasteboard = .general,
        onCapture: @escaping (ClipboardCapture) -> Void
    ) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
        self.onCapture = onCapture
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.checkPasteboard() }
        }
        timer?.tolerance = 0.15
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }

    private func checkPasteboard() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let value = pasteboard.string(forType: .string) {
            let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty, text.count <= 100_000 {
                onCapture(.text(text))
                return
            }
        }

        guard let image = NSImage(pasteboard: pasteboard),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]),
              bitmap.pixelsWide > 0,
              bitmap.pixelsHigh > 0 else { return }

        let digest = SHA256.hash(data: pngData)
            .map { String(format: "%02x", $0) }
            .joined()
        onCapture(.image(
            data: pngData,
            width: bitmap.pixelsWide,
            height: bitmap.pixelsHigh,
            digest: digest
        ))
    }
}
