import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var requiresApproval = false
    @Published private(set) var errorMessage: String?

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        requiresApproval = status == .requiresApproval
    }

    func setEnabled(_ shouldEnable: Bool) {
        do {
            if shouldEnable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

struct SettingsView: View {
    @ObservedObject var store: ClipboardStore
    @StateObject private var launchAtLogin = LaunchAtLoginManager()

    var body: some View {
        Form {
            Section("История") {
                Picker("Максимум записей", selection: $store.historyLimit) {
                    Text("50").tag(50)
                    Text("100").tag(100)
                    Text("200").tag(200)
                    Text("500").tag(500)
                    Text("1000").tag(1000)
                }
                .pickerStyle(.menu)

                Text("Лимит применяется одновременно к тексту и изображениям. Закреплённые записи не удаляются автоматически.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Автозапуск") {
                Toggle(
                    "Запускать при входе в macOS",
                    isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    )
                )

                if launchAtLogin.requiresApproval {
                    Label("Автозапуск ожидает подтверждения в системных настройках.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if launchAtLogin.isEnabled {
                    Label("Clipboard Vault будет запускаться автоматически и появляться в строке меню.", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Автозапуск выключен. Приложение можно включить в любое время.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Открыть настройки объектов входа") {
                    launchAtLogin.openSystemSettings()
                }
                .font(.caption)

                if let errorMessage = launchAtLogin.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Приватность") {
                Toggle("Сохранять новые копирования", isOn: $store.isMonitoringEnabled)

                Text("Clipboard Vault хранит текст и изображения только на этом Mac. Изображения сохраняются как локальные PNG-файлы; сеть не используется.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("О приложении") {
                LabeledContent("Версия", value: "1.2")
                LabeledContent("Формат истории", value: "JSON + локальные PNG")
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 500)
        .padding()
        .onAppear {
            launchAtLogin.refresh()
        }
    }
}
