import AppKit
import Carbon
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

struct HotKeyRecorderView: View {
    @ObservedObject var hotKeyManager: GlobalHotKeyManager
    @State private var isRecording = false
    @State private var keyMonitor: Any?

    var body: some View {
        HStack(spacing: 10) {
            Button {
                isRecording.toggle()
            } label: {
                Text(isRecording ? "Нажмите сочетание…" : hotKeyManager.configuration.displayName)
                    .monospacedDigit()
                    .frame(minWidth: 110)
            }
            .buttonStyle(.bordered)

            Button("Сбросить") {
                hotKeyManager.resetToDefault()
            }
            .disabled(hotKeyManager.configuration == .default)
        }
        .onAppear {
            installKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isRecording else { return event }

            if event.keyCode == UInt16(kVK_Escape) {
                isRecording = false
                return nil
            }

            guard let configuration = HotKeyConfiguration.from(event: event) else {
                NSSound.beep()
                return nil
            }

            hotKeyManager.update(configuration)
            isRecording = false
            return nil
        }
    }

    private func removeKeyMonitor() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }
}

struct SettingsView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var hotKeyManager: GlobalHotKeyManager
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

            Section("Горячая клавиша") {
                LabeledContent("Открыть историю") {
                    HotKeyRecorderView(hotKeyManager: hotKeyManager)
                }

                Text("Нажмите на сочетание, затем удерживайте хотя бы один модификатор (⌃, ⌥, ⇧ или ⌘) и нужную клавишу. Повторное нажатие открывает или скрывает окно истории.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let errorMessage = hotKeyManager.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
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
                LabeledContent("Версия", value: "1.3")
                LabeledContent("Формат истории", value: "JSON + локальные PNG")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 590)
        .padding()
        .onAppear {
            launchAtLogin.refresh()
        }
    }
}
