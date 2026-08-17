import AppKit
import SwiftUI

@MainActor
final class HistoryPanelController: ObservableObject {
    private var panel: NSPanel?

    func toggle(store: ClipboardStore) {
        if panel?.isVisible == true {
            panel?.orderOut(nil)
        } else {
            show(store: store)
        }
    }

    private func show(store: ClipboardStore) {
        if panel == nil {
            let hostingController = NSHostingController(
                rootView: ClipboardMenuView(store: store)
            )
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 580),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.contentViewController = hostingController
            panel.title = "История Clipboard Vault"
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.center()
            self.panel = panel
        }

        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }
}

@main
struct ClipboardVaultApp: App {
    @StateObject private var store: ClipboardStore
    @StateObject private var hotKeyManager: GlobalHotKeyManager
    @StateObject private var historyPanelController: HistoryPanelController

    init() {
        let store = ClipboardStore()
        let hotKeyManager = GlobalHotKeyManager()
        let historyPanelController = HistoryPanelController()

        hotKeyManager.onHotKeyPressed = {
            historyPanelController.toggle(store: store)
        }

        _store = StateObject(wrappedValue: store)
        _hotKeyManager = StateObject(wrappedValue: hotKeyManager)
        _historyPanelController = StateObject(wrappedValue: historyPanelController)
    }

    var body: some Scene {
        MenuBarExtra("Clipboard Vault", systemImage: "rectangle.on.rectangle") {
            ClipboardMenuView(store: store)
                .onAppear {
                    store.startMonitoringIfNeeded()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store, hotKeyManager: hotKeyManager)
        }
    }
}
