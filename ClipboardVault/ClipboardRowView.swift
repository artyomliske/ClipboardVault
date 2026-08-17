import AppKit
import SwiftUI

struct ClipboardRowView: View {
    let item: ClipboardItem
    @ObservedObject var store: ClipboardStore

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                store.copyToPasteboard(item)
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    if item.isImage {
                        imagePreview
                    } else {
                        Text(item.preview)
                            .font(.body)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: 6) {
                        if item.isImage {
                            Label("Изображение", systemImage: "photo")
                        }
                        if item.isPinned {
                            Label("Закреплено", systemImage: "pin.fill")
                        }
                        Text(item.createdAt.formatted(.relative(presentation: .named)))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isImage ? "Скопировать изображение" : "Скопировать: \(item.preview)")

            Menu {
                Button(item.isPinned ? "Открепить" : "Закрепить") {
                    store.togglePinned(item)
                }
                Button("Копировать", systemImage: item.isImage ? "photo.on.rectangle" : "doc.on.doc") {
                    store.copyToPasteboard(item)
                }
                Divider()
                Button("Удалить", systemImage: "trash", role: .destructive) {
                    store.delete(item)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button(item.isPinned ? "Открепить" : "Закрепить") {
                store.togglePinned(item)
            }
            Button("Копировать") {
                store.copyToPasteboard(item)
            }
            Divider()
            Button("Удалить", role: .destructive) {
                store.delete(item)
            }
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let data = store.imageData(for: item), let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 240, maxHeight: 120, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
        } else {
            Label("Изображение недоступно", systemImage: "photo.badge.exclamationmark")
                .foregroundStyle(.secondary)
        }
    }
}
