import SwiftUI

struct ContentView: View {
    @Environment(Store.self) private var store
    @State private var selection: ListSelection? = .myDay

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            if let selection {
                TaskListView(selection: selection)
                    .id(selection)
            } else {
                ContentUnavailableView("Bir liste seçin", systemImage: "list.bullet")
            }
        }
        .onChange(of: store.data.lists) {
            // Silinen liste seçiliyse Görevler'e dön.
            if case .list(let id) = selection, store.list(id) == nil {
                selection = .list(Store.inboxID)
            }
        }
    }
}
