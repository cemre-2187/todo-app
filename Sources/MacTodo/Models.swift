import SwiftUI

struct TaskStep: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var isCompleted = false
}

struct TodoItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    /// Açıklamanın düz metin hâli (satırdaki not simgesi ve eski kayıtlar için).
    var notes = ""
    /// Açıklamanın biçimlendirilmiş hâli (RTF).
    var notesRTF: Data?
    var isCompleted = false
    var isImportant = false
    var dueDate: Date?
    /// Görev Günüm'e eklendiğinde dolar; kullanıcı kaldırana kadar Günüm'de kalır.
    var myDayDate: Date?
    var myDayTab: MyDayTab?
    var listID: UUID
    var steps: [TaskStep] = []
    var createdAt = Date()
    var completedAt: Date?

    var isInMyDay: Bool { myDayDate != nil }

    /// Günüm'deyse hangi sekmede olduğu; eski kayıtlarda sekme yoksa Günüm sayılır.
    var dayTab: MyDayTab? { isInMyDay ? (myDayTab ?? .today) : nil }

    var isOverdue: Bool {
        guard let dueDate, !isCompleted else { return false }
        return dueDate < Calendar.current.startOfDay(for: Date())
    }
}

enum MyDayTab: String, Codable, CaseIterable {
    case today, niceToHave
}

struct TodoList: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var icon = "list.bullet"
}

enum Background: Codable, Hashable {
    case preset(String)
    case image(String)
}

enum ListSelection: Hashable {
    case myDay, niceToHave, important, planned
    case list(UUID)

    var key: String {
        switch self {
        case .myDay: "myDay"
        case .niceToHave: "niceToHave"
        case .important: "important"
        case .planned: "planned"
        case .list(let id): "list-\(id.uuidString)"
        }
    }

    /// Günüm seçiliyken aktif sekmeye göre Günüm ya da Nice to have.
    func resolved(_ tab: MyDayTab) -> ListSelection {
        self == .myDay && tab == .niceToHave ? .niceToHave : self
    }

    var isSmart: Bool {
        if case .list = self { return false }
        return true
    }
}

struct AppData: Codable {
    var lists: [TodoList]
    var tasks: [TodoItem]
    var backgrounds: [String: Background]
    var niceToHaveName: String?
    var sidebarColorHex: String?
}

struct BackgroundPreset: Identifiable {
    let id: String
    let name: String
    let colors: [Color]

    static let all: [BackgroundPreset] = [
        .init(id: "sky", name: "Gökyüzü", colors: [Color(hex: 0x56CCF2), Color(hex: 0x2F80ED)]),
        .init(id: "ocean", name: "Okyanus", colors: [Color(hex: 0x1E3C72), Color(hex: 0x2A5298)]),
        .init(id: "sunset", name: "Gün Batımı", colors: [Color(hex: 0xFF7E5F), Color(hex: 0xFEB47B)]),
        .init(id: "rose", name: "Gül", colors: [Color(hex: 0xE96443), Color(hex: 0x904E95)]),
        .init(id: "lavender", name: "Lavanta", colors: [Color(hex: 0x654EA3), Color(hex: 0xEAAFC8)]),
        .init(id: "forest", name: "Orman", colors: [Color(hex: 0x134E5E), Color(hex: 0x71B280)]),
        .init(id: "mint", name: "Nane", colors: [Color(hex: 0x11998E), Color(hex: 0x38EF7D)]),
        .init(id: "peach", name: "Şeftali", colors: [Color(hex: 0xED4264), Color(hex: 0xFFEDBC)]),
        .init(id: "night", name: "Gece", colors: [Color(hex: 0x0F2027), Color(hex: 0x203A43), Color(hex: 0x2C5364)]),
        .init(id: "graphite", name: "Grafit", colors: [Color(hex: 0x232526), Color(hex: 0x414345)]),
    ]

    static func find(_ id: String) -> BackgroundPreset {
        all.first { $0.id == id } ?? all[0]
    }
}

extension Color {
    static let sidebarPresets: [Color] = [
        Color(hex: 0xFFFFFF), Color(hex: 0xF3EDE4), Color(hex: 0xFDE8EF), Color(hex: 0xE6F0FB),
        Color(hex: 0xE5F4EA), Color(hex: 0xEEE8F8), Color(hex: 0x2B2D31), Color(hex: 0x1F2A44),
        Color(hex: 0x23392F), Color(hex: 0x3B2546),
    ]

    init?(hexString: String) {
        guard let value = UInt32(hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16)
        else { return nil }
        self.init(hex: value)
    }

    var hexString: String? {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(format: "%02X%02X%02X", r, g, b)
    }

    /// Koyu renklerde yazının açık renkte gösterilmesi için.
    var isDark: Bool {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return false }
        let luminance = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
        return luminance < 0.5
    }

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
