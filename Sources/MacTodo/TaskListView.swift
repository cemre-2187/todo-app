import SwiftUI
import UniformTypeIdentifiers

struct TaskListView: View {
    @Environment(Store.self) private var store
    let selection: ListSelection

    @State private var selectedTaskID: UUID?
    @State private var draggedTaskID: UUID?
    @State private var newTitle = ""
    @State private var showCompleted = true
    @State private var showBackgroundPicker = false
    @State private var isDropTargeted = false
    @AppStorage("myDayTab") private var myDayTab: MyDayTab = .today
    @FocusState private var titleFocused: Bool
    @FocusState private var addFocused: Bool

    private var current: ListSelection { selection.resolved(myDayTab) }

    var body: some View {
        let tasks = store.tasks(for: current)
        let open = tasks.filter { !$0.isCompleted }
        let done = tasks.filter(\.isCompleted)

        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(open) { taskRow($0) }

                    if !done.isEmpty {
                        completedHeader(count: done.count)
                        if showCompleted {
                            ForEach(done) { taskRow($0) }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 8)
                .animation(.snappy, value: tasks)
            }
            .overlay {
                if tasks.isEmpty { emptyState }
            }

            addBar
        }
        .background {
            WindowSpanningBackground(background: store.background(for: current))
                .ignoresSafeArea()
                .overlay {
                    if isDropTargeted {
                        Color.white.opacity(0.2)
                            .overlay(Label("Arka plan olarak bırak", systemImage: "photo").font(.title2.bold()).foregroundStyle(.white))
                            .ignoresSafeArea()
                    }
                }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { UTType(filenameExtension: $0.pathExtension)?.conforms(to: .image) == true })
            else { return false }
            return (try? store.importImage(from: url, for: current)) != nil
        } isTargeted: { isDropTargeted = $0 }
        .navigationTitle(store.title(for: current))
        .toolbar {
            ToolbarItem {
                Button {
                    showBackgroundPicker.toggle()
                } label: {
                    Label("Arka plan", systemImage: "paintpalette")
                }
                .help("Arka planı değiştir")
                .popover(isPresented: $showBackgroundPicker, arrowEdge: .bottom) {
                    BackgroundPicker(selection: current)
                }
            }
        }
        .inspector(isPresented: Binding(
            get: { selectedTaskID != nil },
            set: { if !$0 { selectedTaskID = nil } }
        )) {
            if let id = selectedTaskID {
                TaskDetailView(taskID: id) { selectedTaskID = nil }
                    .id(id)
                    .inspectorColumnWidth(min: 280, ideal: 320, max: 440)
            }
        }
        .onChange(of: myDayTab) {
            selectedTaskID = nil
            draggedTaskID = nil
        }
        .onAppear {
            if case .list(let id) = selection, store.pendingRenameListID == id {
                store.pendingRenameListID = nil
                DispatchQueue.main.async { titleFocused = true }
            }
        }
    }

    // MARK: - Başlık

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            if selection == .myDay {
                dayTabs.padding(.bottom, 10)
            }

            HStack(spacing: 10) {
                Image(systemName: store.icon(for: current))
                    .font(.system(size: 26, weight: .semibold))

                if current == .niceToHave {
                    TextField("Sekme adı", text: Binding(
                        get: { store.data.niceToHaveName ?? store.niceToHaveTitle },
                        set: { store.renameNiceToHave($0) }
                    ))
                    .textFieldStyle(.plain)
                    .focused($titleFocused)
                    .onSubmit { titleFocused = false }
                } else if case .list(let id) = selection, id != Store.inboxID {
                    TextField("Liste adı", text: Binding(
                        get: { store.list(id)?.name ?? "" },
                        set: { store.renameList(id, to: $0) }
                    ))
                    .textFieldStyle(.plain)
                    .focused($titleFocused)
                    .onSubmit { titleFocused = false }
                } else {
                    Text(store.title(for: current))
                }
            }
            .font(.system(size: 30, weight: .bold))

            if current == .myDay {
                Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.title3)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var dayTabs: some View {
        HStack(spacing: 4) {
            ForEach(MyDayTab.allCases, id: \.self) { tab in
                let item: ListSelection = tab == .today ? .myDay : .niceToHave
                let isActive = myDayTab == tab
                Button {
                    withAnimation(.snappy) { myDayTab = tab }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: store.icon(for: item))
                        Text(store.title(for: item))
                        let count = store.openCount(for: item)
                        if count > 0 {
                            Text("\(count)").foregroundStyle(.secondary)
                        }
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isActive ? Color.primary : Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        if isActive {
                            Capsule().fill(.regularMaterial)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.black.opacity(0.18)))
        .shadow(radius: 0)
    }

    // MARK: - Satırlar

    private func taskRow(_ task: TodoItem) -> some View {
        TaskRow(
            task: task,
            showListName: current.isSmart,
            isSelected: selectedTaskID == task.id
        )
        .onTapGesture { selectedTaskID = task.id }
        .contextMenu {
            Button(task.isInMyDay ? "Günüm'den kaldır" : "Günüm'e ekle", systemImage: "sun.max") {
                store.toggleMyDay(task.id)
            }
            if let tab = task.dayTab {
                let other: MyDayTab = tab == .today ? .niceToHave : .today
                let otherTitle = store.title(for: other == .today ? .myDay : .niceToHave)
                Button("\(otherTitle) sekmesine taşı", systemImage: "arrow.left.arrow.right") {
                    withAnimation(.snappy) { store.moveToDayTab(task.id, other) }
                }
            }
            Button(task.isImportant ? "Önemli işaretini kaldır" : "Önemli olarak işaretle", systemImage: "star") {
                store.toggleImportant(task.id)
            }
            Button(task.isCompleted ? "Tamamlanmadı olarak işaretle" : "Tamamlandı olarak işaretle",
                   systemImage: "checkmark.circle") {
                store.toggleComplete(task.id)
            }
            Menu("Görevi taşı") {
                ForEach(store.data.lists) { list in
                    Button(list.name) { store.update(task.id) { $0.listID = list.id } }
                        .disabled(list.id == task.listID)
                }
            }
            Divider()
            Button("Görevi sil", systemImage: "trash", role: .destructive) {
                if selectedTaskID == task.id { selectedTaskID = nil }
                store.deleteTask(task.id)
            }
        }
        // Planlanan son tarihe göre sıralı olduğu için elle sıralanamaz.
        .modifier(Reorderable(task: task, draggedID: $draggedTaskID, isEnabled: current != .planned))
    }

    private func completedHeader(count: Int) -> some View {
        Button {
            withAnimation(.snappy) { showCompleted.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(showCompleted ? 90 : 0))
                Text("Tamamlanan")
                Text("\(count)").foregroundStyle(.secondary)
            }
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: current == .myDay ? "sun.haze" : current == .niceToHave ? "sparkles" : "checklist")
                .font(.system(size: 44))
            Text(current == .myDay ? "Gününe odaklan" : current == .niceToHave ? "Vakit olursa yapılacaklar" : "Henüz görev yok")
                .font(.title3.bold())
            Text("Aşağıdan yeni bir görev ekleyebilirsin.")
                .font(.callout)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 4)
        .allowsHitTesting(false)
    }

    // MARK: - Görev ekleme

    private var addBar: some View {
        HStack(spacing: 12) {
            Image(systemName: addFocused ? "circle" : "plus")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 22)
            TextField("Görev ekle", text: $newTitle)
                .textFieldStyle(.plain)
                .focused($addFocused)
                .onSubmit {
                    withAnimation(.snappy) { store.addTask(title: newTitle, to: current) }
                    newTitle = ""
                    addFocused = true
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { addFocused = true }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }
}

/// Satırı sürükle bırak ile sıralanabilir yapar; sürüklenen görev üzerine gelinen
/// görevin yerine anında taşınır.
private struct Reorderable: ViewModifier {
    @Environment(Store.self) private var store
    let task: TodoItem
    @Binding var draggedID: UUID?
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .onDrag {
                    draggedID = task.id
                    return NSItemProvider(object: task.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: TaskDropDelegate(store: store, target: task, draggedID: $draggedID))
        } else {
            content
        }
    }
}

private struct TaskDropDelegate: DropDelegate {
    let store: Store
    let target: TodoItem
    @Binding var draggedID: UUID?

    func dropEntered(info: DropInfo) {
        // Açık ve tamamlanan görevler kendi bölümlerinde sıralanır.
        guard let draggedID, draggedID != target.id,
              store.task(draggedID)?.isCompleted == target.isCompleted
        else { return }
        withAnimation(.snappy) { store.moveTask(draggedID, to: target.id) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedID = nil
        return true
    }
}

struct TaskRow: View {
    @Environment(Store.self) private var store
    let task: TodoItem
    let showListName: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { store.toggleComplete(task.id) }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.blue : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? "Tamamlanmadı olarak işaretle" : "Tamamlandı olarak işaretle")

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                if !metadata.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(metadata.enumerated()), id: \.offset) { index, item in
                            if index > 0 { Text("•") }
                            item
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Button {
                store.toggleImportant(task.id)
            } label: {
                Image(systemName: task.isImportant ? "star.fill" : "star")
                    .foregroundStyle(task.isImportant ? Color.blue : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .help(task.isImportant ? "Önemli işaretini kaldır" : "Önemli olarak işaretle")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor, lineWidth: isSelected ? 2 : 0)
        }
        .contentShape(Rectangle())
    }

    private var metadata: [AnyView] {
        var items: [AnyView] = []
        if let tab = task.dayTab {
            let item: ListSelection = tab == .today ? .myDay : .niceToHave
            items.append(AnyView(Label(store.title(for: item), systemImage: store.icon(for: item))))
        }
        if showListName, let list = store.list(task.listID) {
            items.append(AnyView(Text(list.name)))
        }
        if !task.steps.isEmpty {
            let done = task.steps.filter(\.isCompleted).count
            items.append(AnyView(Text("\(done)/\(task.steps.count)")))
        }
        if let due = task.dueDate {
            items.append(AnyView(
                Label(DueDateText.format(due), systemImage: "calendar")
                    .foregroundStyle(task.isOverdue ? Color.red : Color.secondary)
            ))
        }
        if !task.notes.isEmpty {
            items.append(AnyView(Image(systemName: "note.text")))
        }
        return items
    }
}

enum DueDateText {
    static func format(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Bugün" }
        if calendar.isDateInTomorrow(date) { return "Yarın" }
        if calendar.isDateInYesterday(date) { return "Dün" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "tr_TR")))
    }
}
