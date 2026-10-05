import SwiftUI

struct SidebarView: View {
    @Environment(Store.self) private var store
    @Binding var selection: ListSelection?
    @State private var listToDelete: TodoList?
    @State private var showColorPicker = false
    @AppStorage("myDayTab") private var myDayTab: MyDayTab = .today

    private let smartLists: [ListSelection] = [.myDay, .important, .planned, .list(Store.inboxID)]

    var body: some View {
        let customColor = store.sidebarColor

        List(selection: $selection) {
            Section {
                ForEach(smartLists, id: \.self) { row($0) }
            }

            Section("Listeler") {
                ForEach(store.userLists) { list in
                    row(.list(list.id))
                        .contextMenu {
                            Button("Listeyi sil", role: .destructive) { listToDelete = list }
                        }
                }
                .onMove { store.moveUserLists(from: $0, to: $1) }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .background { background(customColor) }
        // Koyu bir renk seçildiyse yazılar okunaklı kalsın.
        .environment(\.colorScheme, customColor.map { $0.isDark ? .dark : .light } ?? colorScheme)
        .alert(
            "\"\(listToDelete?.name ?? "")\" silinsin mi?",
            isPresented: Binding(get: { listToDelete != nil }, set: { if !$0 { listToDelete = nil } })
        ) {
            Button("Sil", role: .destructive) {
                if let list = listToDelete { store.deleteList(list.id) }
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Bu listedeki tüm görevler kalıcı olarak silinecek.")
        }
    }

    @Environment(\.colorScheme) private var colorScheme

    /// Seçili listenin arka planı menüye doğru uzar; üstüne seçilen menü rengi
    /// yarı saydam, renk yoksa buzlu cam katmanı gelir.
    private func background(_ customColor: Color?) -> some View {
        let current = (selection ?? .myDay).resolved(myDayTab)
        return WindowSpanningBackground(background: store.background(for: current))
            .blur(radius: 24, opaque: true)
            .overlay {
                if let customColor {
                    customColor.opacity(0.6)
                } else {
                    Rectangle().fill(.thinMaterial)
                }
            }
            .ignoresSafeArea()
    }

    private var bottomBar: some View {
        HStack {
            Button {
                selection = .list(store.addList())
            } label: {
                Label("Yeni liste", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)

            Button {
                showColorPicker.toggle()
            } label: {
                Image(systemName: "paintbrush")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Menü rengini değiştir")
            .popover(isPresented: $showColorPicker, arrowEdge: .top) {
                SidebarColorPicker()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func row(_ item: ListSelection) -> some View {
        let count = store.openCount(for: item)
        return Label {
            Text(store.title(for: item))
        } icon: {
            Image(systemName: store.icon(for: item))
                .foregroundStyle(store.tint(for: item))
        }
        .badge(count > 0 ? count : 0)
        .tag(item)
    }
}

struct SidebarColorPicker: View {
    @Environment(Store.self) private var store
    private let columns = Array(repeating: GridItem(.fixed(32), spacing: 10), count: 5)

    var body: some View {
        let current = store.data.sidebarColorHex

        VStack(alignment: .leading, spacing: 12) {
            Text("Menü rengi").font(.headline)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Color.sidebarPresets, id: \.self) { color in
                    Button {
                        store.setSidebarColor(color)
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 32, height: 32)
                            .overlay {
                                Circle().strokeBorder(
                                    current == color.hexString ? Color.accentColor : Color.primary.opacity(0.15),
                                    lineWidth: current == color.hexString ? 3 : 1
                                )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            ColorPicker("Özel renk", selection: Binding(
                get: { store.sidebarColor ?? .white },
                set: { store.setSidebarColor($0) }
            ), supportsOpacity: false)

            Button("Varsayılana dön") { store.setSidebarColor(nil) }
                .disabled(current == nil)
        }
        .padding(16)
        .frame(width: 240)
    }
}
