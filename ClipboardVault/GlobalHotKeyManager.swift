import AppKit
import Carbon
import Combine
import Foundation

struct HotKeyConfiguration: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let `default` = HotKeyConfiguration(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | optionKey)
    )

    var displayName: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    static func from(event: NSEvent) -> HotKeyConfiguration? {
        var carbonModifiers: UInt32 = 0
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }

        guard carbonModifiers != 0 else { return nil }
        return HotKeyConfiguration(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers)
    }

    private static func keyName(for keyCode: UInt32) -> String {
        let names: [UInt32: String] = [
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
            UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
            UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
            UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
            UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
            UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
            UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
            UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
            UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
            UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
            UInt32(kVK_ANSI_9): "9", UInt32(kVK_Space): "Пробел",
            UInt32(kVK_Return): "↩", UInt32(kVK_Tab): "⇥", UInt32(kVK_Escape): "⎋"
        ]
        return names[keyCode] ?? "Клавиша \(keyCode)"
    }
}

private let hotKeySignature: OSType = 0x43564C54 // CVLT
private let hotKeyIdentifier: UInt32 = 1

private func hotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return noErr }

    var eventID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &eventID
    )

    guard status == noErr,
          eventID.signature == hotKeySignature,
          eventID.id == hotKeyIdentifier else { return noErr }

    DispatchQueue.main.async {
        GlobalHotKeyManager.shared?.onHotKeyPressed?()
    }
    return noErr
}

@MainActor
final class GlobalHotKeyManager: ObservableObject {
    @Published private(set) var configuration: HotKeyConfiguration
    @Published private(set) var errorMessage: String?

    static weak var shared: GlobalHotKeyManager?
    var onHotKeyPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let storageKey = "globalHistoryHotKey"

    init() {
        configuration = Self.loadConfiguration() ?? .default
        Self.shared = self
        installEventHandler()
        register(configuration)
    }

    func update(_ newConfiguration: HotKeyConfiguration) {
        guard newConfiguration != configuration else { return }

        let previousConfiguration = configuration
        unregisterCurrentHotKey()

        guard register(newConfiguration) else {
            errorMessage = "Не удалось зарегистрировать сочетание \(newConfiguration.displayName). Возможно, оно уже используется другим приложением."
            _ = register(previousConfiguration)
            return
        }

        configuration = newConfiguration
        saveConfiguration(newConfiguration)
        errorMessage = nil
    }

    func resetToDefault() {
        update(.default)
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
        if status != noErr {
            errorMessage = "Не удалось подготовить обработчик глобальной горячей клавиши."
        }
    }

    @discardableResult
    private func register(_ configuration: HotKeyConfiguration) -> Bool {
        var reference: EventHotKeyRef?
        let eventID = EventHotKeyID(signature: hotKeySignature, id: hotKeyIdentifier)
        let status = RegisterEventHotKey(
            configuration.keyCode,
            configuration.modifiers,
            eventID,
            GetApplicationEventTarget(),
            0,
            &reference
        )

        guard status == noErr else { return false }
        hotKeyRef = reference
        return true
    }

    private func unregisterCurrentHotKey() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    private static func loadConfiguration() -> HotKeyConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: "globalHistoryHotKey") else { return nil }
        return try? JSONDecoder().decode(HotKeyConfiguration.self, from: data)
    }

    private func saveConfiguration(_ configuration: HotKeyConfiguration) {
        let data = try? JSONEncoder().encode(configuration)
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
