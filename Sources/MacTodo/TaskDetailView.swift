import SwiftUI

struct TaskDetailView: View {
    @Environment(Store.self) private var store
    let taskID: UUID
    let onClose: () -> Void

    @State private var editor = RichTextController()

    var body: some View {
        if let task = store.binding(for: taskID) {
            content(task)
        } else {
            ContentUnavailableView("Görev bulunamadı", systemImage: "questionmark.circle")
        }
    }

    private func content(_ task: Binding<TodoItem>) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                checkbox(task.wrappedValue.isCompleted) { store.toggleComplete(taskID) }
                TextField("Görev adı", text: task.title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .strikethrough(task.wrappedValue.isCompleted)
                Button {
                    store.toggleImportant(taskID)
                } label: {
                    Image(systemName: task.wrappedValue.isImportant ? "star.fill" : "star")
                        .foregroundStyle(task.wrappedValue.isImportant ? Color.blue : Color.secondary)
                }
                .buttonStyle(.plain)
            }
            .font(.title3.weight(.semibold))
            .padding(14)

            Divider()

            FormatBar(controller: editor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

            Divider()

            RichTextEditor(
                rtf: task.wrappedValue.notesRTF,
                fallbackText: task.wrappedValue.notes,
                controller: editor
            ) { rtf, plain in
                store.update(taskID) {
                    $0.notesRTF = rtf
                    $0.notes = plain
                }
            }
            .overlay(alignment: .topLeading) {
                if editor.isEmpty {
                    Text("Açıklama ekle…")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 15)
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }
            }

            Divider()

            HStack {
                Button(action: onClose) {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.borderless)
                .help("Paneli kapat")

                Spacer()
                Text("Oluşturulma: \(task.wrappedValue.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()

                Button(role: .destructive) {
                    onClose()
                    store.deleteTask(taskID)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Görevi sil")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func checkbox(_ checked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(checked ? Color.blue : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}
