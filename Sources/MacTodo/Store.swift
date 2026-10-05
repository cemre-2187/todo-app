import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class Store {
    static let inboxID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    var data: AppData {
        didSet { scheduleSave() }
    }

    /// Kullanıcının içe aktardığı arka plan resimlerinin dosya adları.
    private(set) var customImages: [String] = []

    /// Yeni oluşturulan listenin başlığına odaklanmak için kullanılır.
    @ObservationIgnored var pendingRenameListID: UUID?

    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var imageCache: [String: NSImage] = [:]
    @ObservationIgnored private var terminateObserver: NSObjectProtocol?

    static let supportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacTodo", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    static let backgroundsDir: URL = {
        let dir = supportDir.appendingPathComponent("Backgrounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static var dataURL: URL { supportDir.appendingPathComponent("data.json") }

    init() {
        if let raw = try? Data(contentsOf: Self.dataURL),
           let decoded = try? JSONDecoder().decode(AppData.self, from: raw) {
            data = decoded
        } else {
            data = AppData(lists: [], tasks: [], backgrounds: [:])
            // Okunamayan bir kayıt varsa üzerine yazmadan önce yedekle.
            if FileManager.default.fileExists(atPath: Self.dataURL.path) {
                let backup = Self.supportDir.appendingPathComponent("data-backup-\(Int(Date().timeIntervalSince1970)).json")
                try? FileManager.default.moveItem(at: Self.dataURL, to: backup)
            }
        }
        if !data.lists.contains(where: { $0.id == Self.inboxID }) {
            data.lists.insert(TodoList(id: Self.inboxID, name: "Görevler", icon: "house"), at: 0)
        }
        customImages = (try? FileManager.default.contentsOfDirectory(atPath: Self.backgroundsDir.path))?
            .filter { !$0.hasPrefix(".") }
            .sorted() ?? []

        terminateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveNow() }
        }
    }

    // MARK: - Kaydetme

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(data).write(to: Self.dataURL, options: .atomic)
        } catch {
            NSLog("MacTodo: kaydetme hatası: \(error)")
        }
    }

    // MARK: - Sorgular

    var userLists: [TodoList] { data.lists.filter { $0.id != Self.inboxID } }

    func list(_ id: UUID) -> TodoList? { data.lists.first { $0.id == id } }

    func tasks(for selection: ListSelection) -> [TodoItem] {
        switch selection {
        case .myDay:
            data.tasks.filter { $0.dayTab == .today }
        case .niceToHave:
            data.tasks.filter { $0.dayTab == .niceToHave }
        case .important:
            data.tasks.filter(\.isImportant)
        case .planned:
            data.tasks.filter { $0.dueDate != nil }.sorted { $0.dueDate! < $1.dueDate! }
        case .list(let id):
            data.tasks.filter { $0.listID == id }
        }
    }

    func openCount(for selection: ListSelection) -> Int {
        tasks(for: selection).filter { !$0.isCompleted }.count
    }

    func title(for selection: ListSelection) -> String {
        switch selection {
        case .myDay: "Günüm"
        case .niceToHave: niceToHaveTitle
        case .important: "Önemli"
        case .planned: "Planlanan"
        case .list(let id): list(id)?.name ?? "Liste"
        }
    }

    func icon(for selection: ListSelection) -> String {
        switch selection {
        case .myDay: "sun.max"
        case .niceToHave: "sparkles"
        case .important: "star"
        case .planned: "calendar"
        case .list(let id): list(id)?.icon ?? "list.bullet"
        }
    }

    func tint(for selection: ListSelection) -> Color {
        switch selection {
        case .myDay: .orange
        case .niceToHave: .purple
        case .important: .pink
        case .planned: .teal
        case .list(let id): id == Self.inboxID ? .blue : .indigo
        }
    }

    var niceToHaveTitle: String {
        let name = data.niceToHaveName ?? ""
        return name.isEmpty ? "Nice to have" : name
    }

    func renameNiceToHave(_ name: String) {
        data.niceToHaveName = name
    }

    // MARK: - Görevler

    func addTask(title: String, to selection: ListSelection) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var item = TodoItem(title: trimmed, listID: Self.inboxID)
        switch selection {
        case .myDay:
            item.myDayDate = Date()
            item.myDayTab = .today
        case .niceToHave:
            item.myDayDate = Date()
            item.myDayTab = .niceToHave
        case .important: item.isImportant = true
        case .planned: item.dueDate = Calendar.current.startOfDay(for: Date())
        case .list(let id): item.listID = id
        }
        data.tasks.insert(item, at: 0)
    }

    func task(_ id: UUID) -> TodoItem? { data.tasks.first { $0.id == id } }

    func update(_ id: UUID, _ change: (inout TodoItem) -> Void) {
        guard let index = data.tasks.firstIndex(where: { $0.id == id }) else { return }
        change(&data.tasks[index])
    }

    func binding(for id: UUID) -> Binding<TodoItem>? {
        guard let initial = task(id) else { return nil }
        return Binding(
            get: { [weak self] in self?.task(id) ?? initial },
            set: { [weak self] newValue in self?.update(id) { $0 = newValue } }
        )
    }

    func toggleComplete(_ id: UUID) {
        update(id) {
            $0.isCompleted.toggle()
            $0.completedAt = $0.isCompleted ? Date() : nil
        }
        if task(id)?.isCompleted == true { playCompletionSound() }
    }

    /// Görev tamamlanınca kısa bir "ding" çalar; art arda tıklamada baştan başlar.
    private func playCompletionSound() {
        guard let sound = NSSound(named: "Glass") else { return }
        sound.stop()
        sound.play()
    }

    func toggleImportant(_ id: UUID) {
        update(id) { $0.isImportant.toggle() }
    }

    func toggleMyDay(_ id: UUID) {
        update(id) {
            if $0.isInMyDay {
                $0.myDayDate = nil
                $0.myDayTab = nil
            } else {
                $0.myDayDate = Date()
                $0.myDayTab = .today
            }
        }
    }

    /// Görevi Günüm'ün verilen sekmesine koyar (Günüm'de değilse ekler).
    func moveToDayTab(_ id: UUID, _ tab: MyDayTab) {
        update(id) {
            $0.myDayDate = $0.myDayDate ?? Date()
            $0.myDayTab = tab
        }
    }

    /// Görevi hedef görevin yerine taşır. Sıra tüm görünümlerin ortak kullandığı
    /// `data.tasks` dizisinden geldiği için filtreli listelerde de doğru çalışır.
    func moveTask(_ id: UUID, to targetID: UUID) {
        guard id != targetID,
              let from = data.tasks.firstIndex(where: { $0.id == id }),
              let to = data.tasks.firstIndex(where: { $0.id == targetID })
        else { return }
        data.tasks.move(fromOffsets: [from], toOffset: to > from ? to + 1 : to)
    }

    func deleteTask(_ id: UUID) {
        data.tasks.removeAll { $0.id == id }
    }

    // MARK: - Adımlar

    func addStep(_ title: String, to taskID: UUID) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        update(taskID) { $0.steps.append(TaskStep(title: trimmed)) }
    }

    func updateStep(_ stepID: UUID, in taskID: UUID, _ change: (inout TaskStep) -> Void) {
        update(taskID) { task in
            guard let index = task.steps.firstIndex(where: { $0.id == stepID }) else { return }
            change(&task.steps[index])
        }
    }

    func deleteStep(_ stepID: UUID, in taskID: UUID) {
        update(taskID) { $0.steps.removeAll { $0.id == stepID } }
    }

    // MARK: - Listeler

    @discardableResult
    func addList(name: String = "Adsız liste") -> UUID {
        let list = TodoList(name: name)
        data.lists.append(list)
        pendingRenameListID = list.id
        return list.id
    }

    func renameList(_ id: UUID, to name: String) {
        guard let index = data.lists.firstIndex(where: { $0.id == id }) else { return }
        data.lists[index].name = name
    }

    func setListIcon(_ id: UUID, to icon: String) {
        guard let index = data.lists.firstIndex(where: { $0.id == id }) else { return }
        data.lists[index].icon = icon
    }

    func deleteList(_ id: UUID) {
        guard id != Self.inboxID else { return }
        data.tasks.removeAll { $0.listID == id }
        data.lists.removeAll { $0.id == id }
        data.backgrounds[ListSelection.list(id).key] = nil
    }

    func moveUserLists(from source: IndexSet, to destination: Int) {
        var lists = userLists
        lists.move(fromOffsets: source, toOffset: destination)
        data.lists = data.lists.filter { $0.id == Self.inboxID } + lists
    }

    // MARK: - Kenar çubuğu rengi

    /// nil = sistemin varsayılan kenar çubuğu.
    var sidebarColor: Color? {
        data.sidebarColorHex.flatMap(Color.init(hexString:))
    }

    func setSidebarColor(_ color: Color?) {
        data.sidebarColorHex = color?.hexString
    }

    // MARK: - Arka planlar

    func background(for selection: ListSelection) -> Background {
        if let bg = data.backgrounds[selection.key] { return bg }
        switch selection {
        case .myDay: return .preset("sky")
        case .niceToHave: return .preset("peach")
        case .important: return .preset("rose")
        case .planned: return .preset("forest")
        case .list(let id): return .preset(id == Self.inboxID ? "ocean" : "lavender")
        }
    }

    func setBackground(_ background: Background, for selection: ListSelection) {
        data.backgrounds[selection.key] = background
    }

    /// Resmi uygulama klasörüne kopyalar ve verilen listenin arka planı yapar.
    func importImage(from url: URL, for selection: ListSelection) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension.lowercased()
        let name = "\(UUID().uuidString).\(ext)"
        try FileManager.default.copyItem(at: url, to: Self.backgroundsDir.appendingPathComponent(name))
        customImages.append(name)
        setBackground(.image(name), for: selection)
    }

    func deleteCustomImage(_ name: String) {
        try? FileManager.default.removeItem(at: Self.backgroundsDir.appendingPathComponent(name))
        customImages.removeAll { $0 == name }
        imageCache[name] = nil
        for (key, bg) in data.backgrounds where bg == .image(name) {
            data.backgrounds[key] = nil
        }
    }

    func image(named name: String) -> NSImage? {
        if let cached = imageCache[name] { return cached }
        let image = NSImage(contentsOf: Self.backgroundsDir.appendingPathComponent(name))
        imageCache[name] = image
        return image
    }
}
