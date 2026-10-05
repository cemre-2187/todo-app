import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BackgroundView: View {
    @Environment(Store.self) private var store
    let background: Background

    var body: some View {
        content
            .overlay(Color.black.opacity(0.12))
    }

    @ViewBuilder
    private var content: some View {
        switch background {
        case .preset(let id):
            LinearGradient(colors: BackgroundPreset.find(id).colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        case .image(let name):
            if let image = store.image(named: name) {
                // Color.clear + overlay: resim, düzeni bozmadan alanı doldurur.
                Color.clear
                    .overlay {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
            } else {
                LinearGradient(colors: BackgroundPreset.all[0].colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
}

struct BackgroundPicker: View {
    @Environment(Store.self) private var store
    let selection: ListSelection
    @State private var errorMessage: String?

    private let columns = Array(repeating: GridItem(.fixed(64), spacing: 10), count: 5)

    var body: some View {
        let current = store.background(for: selection)

        VStack(alignment: .leading, spacing: 14) {
            Text("Tema").font(.headline)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(BackgroundPreset.all) { preset in
                    Button {
                        store.setBackground(.preset(preset.id), for: selection)
                    } label: {
                        LinearGradient(colors: preset.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(width: 64, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(selectionRing(current == .preset(preset.id)))
                    }
                    .buttonStyle(.plain)
                    .help(preset.name)
                }
            }

            Divider()

            HStack {
                Text("Kendi resimlerin").font(.headline)
                Spacer()
                Button("Resim seç…", systemImage: "photo.badge.plus", action: pickImage)
            }

            if store.customImages.isEmpty {
                Text("Bilgisayarından bir resim seç ya da resmi pencereye sürükleyip bırak.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(store.customImages, id: \.self) { name in
                        Button {
                            store.setBackground(.image(name), for: selection)
                        } label: {
                            thumbnail(name)
                                .overlay(selectionRing(current == .image(name)))
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Resmi sil", role: .destructive) { store.deleteCustomImage(name) }
                        }
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(width: 400)
    }

    private func thumbnail(_ name: String) -> some View {
        Color.gray.opacity(0.2)
            .frame(width: 64, height: 44)
            .overlay {
                if let image = store.image(named: name) {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func selectionRing(_ selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: selected ? 3 : 1)
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Arka plan yap"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.importImage(from: url, for: selection)
            errorMessage = nil
        } catch {
            errorMessage = "Resim eklenemedi: \(error.localizedDescription)"
        }
    }
}
