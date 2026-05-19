import SwiftUI

struct TodoPanelView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if store.selectedTodos.isEmpty {
                Text("No todos yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else if store.todoViewMode == .kanban {
                TodoKanbanView()
            } else {
                TodoListView()
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.55))
        )
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Project Todos", systemImage: "checklist")
                    .font(.headline)
                Text("\(store.completedTodoCount)/\(store.selectedTodos.count)")
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    store.addTodo()
                } label: {
                    Label("Add Todo", systemImage: "plus")
                }
            }

            HStack {
                Picker("View", selection: $store.todoViewMode) {
                    ForEach(TodoViewMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)

                Picker("Filter", selection: $store.todoFilter) {
                    ForEach(TodoFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .frame(width: 150)

                Spacer()

                if store.todoFilter != .all {
                    Button("Clear Filter") {
                        store.todoFilter = .all
                        store.save()
                    }
                    .buttonStyle(.borderless)
                }
            }
            .onChange(of: store.todoViewMode) { _, _ in store.save() }
            .onChange(of: store.todoFilter) { _, _ in store.save() }
        }
    }
}

private struct TodoListView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        if store.filteredTodos.isEmpty {
            Text("No todos match this filter")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(store.filteredTodos) { todo in
                    TodoRowView(todo: todo)
                    if todo.id != store.filteredTodos.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

private struct TodoKanbanView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(TodoStatus.allCases) { status in
                TodoKanbanColumn(status: status, todos: store.filteredTodos.filter { $0.status == status })
            }
        }
    }
}

private struct TodoKanbanColumn: View {
    var status: TodoStatus
    var todos: [ProjectTodo]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(status.title, systemImage: status.symbolName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(todos.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if todos.isEmpty {
                Text("Empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .center)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 8) {
                    ForEach(todos) { todo in
                        TodoKanbanCard(todo: todo)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TodoKanbanCard: View {
    @EnvironmentObject private var store: ProgressStore
    var todo: ProjectTodo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(todo.title)
                .font(.callout.weight(.semibold))
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                .lineLimit(3)

            HStack {
                Button {
                    store.setTodoStatus(todo, status: previousStatus)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(todo.status == .todo)
                .help("Move left")

                Picker("Status", selection: Binding(
                    get: { todo.status },
                    set: { store.setTodoStatus(todo, status: $0) }
                )) {
                    ForEach(TodoStatus.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }
                .labelsHidden()

                Button {
                    store.setTodoStatus(todo, status: nextStatus)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(todo.status == .done)
                .help("Move right")
            }
        }
        .padding(10)
        .background(.background.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
        .contextMenu {
            Button("Mark To Do") { store.setTodoStatus(todo, status: .todo) }
            Button("Mark Doing") { store.setTodoStatus(todo, status: .doing) }
            Button("Mark Done") { store.setTodoStatus(todo, status: .done) }
            Divider()
            Button("Remove Todo", role: .destructive) {
                store.removeTodo(todo)
            }
        }
    }

    private var previousStatus: TodoStatus {
        switch todo.status {
        case .todo: .todo
        case .doing: .todo
        case .done: .doing
        }
    }

    private var nextStatus: TodoStatus {
        switch todo.status {
        case .todo: .doing
        case .doing: .done
        case .done: .done
        }
    }
}

private struct TodoRowView: View {
    @EnvironmentObject private var store: ProgressStore
    var todo: ProjectTodo

    var body: some View {
        HStack(spacing: 10) {
            Button {
                store.setTodoCompletion(todo, completed: todo.status != .done)
            } label: {
                Image(systemName: todo.status.symbolName)
                    .foregroundStyle(todo.status == .done ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(todo.title)
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                .lineLimit(1)

            Spacer()

            Picker("Status", selection: Binding(
                get: { todo.status },
                set: { store.setTodoStatus(todo, status: $0) }
            )) {
                ForEach(TodoStatus.allCases) { status in
                    Text(status.title).tag(status)
                }
            }
            .labelsHidden()
            .frame(width: 116)

            Text(DisplayFormat.relativeDay(todo.completedAt ?? todo.createdAt))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Mark To Do") { store.setTodoStatus(todo, status: .todo) }
            Button("Mark Doing") { store.setTodoStatus(todo, status: .doing) }
            Button("Mark Done") { store.setTodoStatus(todo, status: .done) }
            Divider()
            Button("Remove Todo", role: .destructive) {
                store.removeTodo(todo)
            }
        }
    }
}
