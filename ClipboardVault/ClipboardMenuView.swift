import AppKit
import SwiftUI

struct ClipboardMenuView: View {
    @ObservedObject var store: ClipboardStore
    @State private var query = ""
    @State private var isCaseSensitive = false

    private var displayedItems: [ClipboardItem] {
        store.displayedItems(matching: query, caseSensitive: isCaseSensitive)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            historyList
            Divider()
            footer
        }
        .frame(minWidth: 430, idealWidth: 480, minHeight: 420, idealHeight: 560)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Clipboard Vault", systemImage: "rectangle.on.rectangle")
                    .font(.headline)
                Spacer()
                Toggle("Сохранение", isOn: $store.isMonitoringEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityLabel("Сохранение истории")
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Поиск в истории", text: $query)
                    .textFieldStyle(.plain)

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Очистить поиск")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
    }

    @ViewBuilder
    private var historyList: some View {
        if displayedItems.isEmpty {
            ContentUnavailableView(
                query.isEmpty ? "История пока пуста" : "Ничего не найдено",
                systemImage: query.isEmpty ? "doc.on.clipboard" : "magnifyingglass",
                description: Text(query.isEmpty
                    ? (store.isMonitoringEnabled ? "Скопируйте текст в любом приложении." : "Включите сохранение, чтобы собирать историю.")
                    : "Измените поисковый запрос или регистр поиска.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(displayedItems) { item in
                ClipboardRowView(item: item, store: store)
            }
            .listStyle(.inset)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text("\(store.items.count) в истории")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Toggle("Регистр", isOn: $isCaseSensitive)
                .toggleStyle(.checkbox)
                .font(.caption)

            SettingsLink {
                Image(systemName: "gearshape")
            }
            .labelStyle(.iconOnly)
            .help("Настройки")

            Menu {
                Button("Удалить незакреплённые", role: .destructive) {
                    store.clearUnpinned()
                }
                Button("Удалить всю историю", role: .destructive) {
                    store.clearAll()
                }
            } label: {
                Label("Очистить", systemImage: "trash")
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help("Выйти из Clipboard Vault")
            .accessibilityLabel("Выйти из Clipboard Vault")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

