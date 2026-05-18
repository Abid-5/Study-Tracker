import SwiftUI

struct TodoPanelView: View {
    @EnvironmentObject private var store: ProgressStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            if store.selectedTodos.isEmpty {
                Text("No todos yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(store.selectedTodos) { todo in
                        TodoRowView(todo: todo)
                        if todo.id != store.selectedTodos.last?.id {
                            Divider()
                        }
                    }
                }
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
}

private struct TodoRowView: View {
    @EnvironmentObject private var store: ProgressStore
    var todo: ProjectTodo

    var body: some View {
        HStack(spacing: 10) {
            Button {
                store.toggleTodo(todo)
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(todo.title)
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                .lineLimit(1)

            Spacer()

            Text(DisplayFormat.relativeDay(todo.completedAt ?? todo.createdAt))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            Button(todo.isCompleted ? "Mark Todo Open" : "Mark Todo Done") {
                store.toggleTodo(todo)
            }
            Button("Remove Todo", role: .destructive) {
                store.removeTodo(todo)
            }
        }
    }
}
