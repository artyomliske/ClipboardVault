import SwiftUI

@main
struct ClipboardVaultApp: App {
    @StateObject private var store = ClipboardStore()

    var body: some Scene {
        MenuBarExtra("Clipboard Vault", systemImage: "rectangle.on.rectangle") {
            ClipboardMenuView(store: store)
                .onAppear {
                    store.startMonitoringIfNeeded()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store)
        }
    }
}
