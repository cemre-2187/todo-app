import SwiftUI

struct TaskDetailView: View {
    @Environment(Store.self) private var store
    let taskID: UUID
    let onClose: () -> Void

    @State private var newStep = ""

    var body: some View {
        if let task = store.binding(for: taskID) {
            content(task)
        } else {
            ContentUnavailableView("Görev bulunamadı", systemImage: "questionmark.circle")
        }
    }

    private func content(_ task: Binding<TodoItem>) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    titleAndSteps(task)
                    myDayCard(task)
                    dueDateCard(task)
                    listCard(task)
                    notesCard(task)
                }
                .padding(14)
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

    // MARK: - Kartlar

    private func titleAndSteps(_ task: Binding<TodoItem>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                checkbox(task.wrappedValue.isCompleted) { store.toggleComplete(taskID) }
                    .font(.title3)
                TextField("Görev adı", text: task.title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.title3.weight(.semibold))
                    .strikethrough(task.wrappedValue.isCompleted)
                Button {
                    store.toggleImportant(taskID)
                } label: {
                    Image(systemName: task.wrappedValue.isImportant ? "star.fill" : "star")
                        .foregroundStyle(task.wrappedValue.isImportant ? Color.blue : Color.secondary)
                }
                .buttonStyle(.plain)
            }

            ForEach(task.wrappedValue.steps) { step in
                HStack(spacing: 10) {
                    checkbox(step.isCompleted) {
                        store.updateStep(step.id, in: taskID) { $0.isCompleted.toggle() }
                    }
                    TextField("Adım", text: Binding(
                        get: { step.title },
                        set: { value in store.updateStep(step.id, in: taskID) { $0.title = value } }
                    ))
                    .textFieldStyle(.plain)
                    .strikethrough(step.isCompleted)
                    .foregroundStyle(step.isCompleted ? .secondary : .primary)
                    Button {
                        store.deleteStep(step.id, in: taskID)
                    } label: {
                        Image(systemName: "xmark").font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Adımı sil")
                }
                .padding(.leading, 4)
            }

            HStack(spacing: 10) {
                Image(systemName: "plus").foregroundStyle(.blue)
                TextField("Sonraki adım", text: $newStep)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        store.addStep(newStep, to: taskID)
                        newStep = ""
                    }
            }
            .padding(.leading, 4)
        }
        .card()
    }

    private func myDayCard(_ task: Binding<TodoItem>) -> some View {
        let inMyDay = task.wrappedValue.isInMyDay
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                store.toggleMyDay(taskID)
            } label: {
                HStack {
                    Label(inMyDay ? "Günüm'e eklendi" : "Günüm'e ekle", systemImage: "sun.max")
                        .foregroundStyle(inMyDay ? Color.blue : Color.primary)
                    Spacer()
                    if inMyDay {
                        Image(systemName: "xmark").foregroundStyle(.secondary).help("Günüm'den kaldır")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let tab = task.wrappedValue.dayTab {
                Picker("Sekme", selection: Binding(
                    get: { tab },
                    set: { store.moveToDayTab(taskID, $0) }
                )) {
                    Text("Günüm").tag(MyDayTab.today)
                    Text(store.niceToHaveTitle).tag(MyDayTab.niceToHave)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .card()
    }

    private func dueDateCard(_ task: Binding<TodoItem>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { task.wrappedValue.dueDate != nil },
                set: { task.wrappedValue.dueDate = $0 ? Calendar.current.startOfDay(for: Date()) : nil }
            )) {
                Label("Son tarih ekle", systemImage: "calendar")
                    .foregroundStyle(task.wrappedValue.isOverdue ? Color.red : Color.primary)
            }
            .toggleStyle(.switch)

            if task.wrappedValue.dueDate != nil {
                DatePicker(
                    "Tarih",
                    selection: Binding(
                        get: { task.wrappedValue.dueDate ?? Date() },
                        set: { task.wrappedValue.dueDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.field)

                HStack {
                    quickDate("Bugün", days: 0, task)
                    quickDate("Yarın", days: 1, task)
                    quickDate("Gelecek hafta", days: 7, task)
                }
                .controlSize(.small)
            }
        }
        .card()
    }

    private func quickDate(_ title: String, days: Int, _ task: Binding<TodoItem>) -> some View {
        Button(title) {
            let today = Calendar.current.startOfDay(for: Date())
            task.wrappedValue.dueDate = Calendar.current.date(byAdding: .day, value: days, to: today)
        }
    }

    private func listCard(_ task: Binding<TodoItem>) -> some View {
        Picker(selection: task.listID) {
            ForEach(store.data.lists) { list in
                Text(list.name).tag(list.id)
            }
        } label: {
            Label("Liste", systemImage: "list.bullet")
        }
        .card()
    }

    private func notesCard(_ task: Binding<TodoItem>) -> some View {
        ZStack(alignment: .topLeading) {
            if task.wrappedValue.notes.isEmpty {
                Text("Not ekle")
                    .foregroundStyle(.tertiary)
                    .padding(.top, 1)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }
            TextEditor(text: task.notes)
                .scrollContentBackground(.hidden)
                .font(.body)
                .frame(minHeight: 120)
        }
        .card()
    }

    private func checkbox(_ checked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(checked ? Color.blue : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func card() -> some View {
        padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.08)))
    }
}
