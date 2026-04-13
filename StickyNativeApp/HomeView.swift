import SwiftUI

struct HomeView: View {
  @ObservedObject var viewModel: HomeViewModel
  let onOpenMemo: (UUID) -> Void
  let onTrashMemo: (UUID) -> Void
  let onRestoreMemo: (UUID) -> Void
  let onEmptyTrash: () -> Void
  let onCreateSession: (String) -> Void
  let onRenameSession: (UUID, String) -> Void
  let onDeleteSession: (UUID) -> Void
  let onAssignSession: (UUID, UUID?) -> Void

  @State private var searchQuery = ""
  @State private var showTrash = false
  @State private var isSessionManagerPresented = false

  private var displayedMemos: [PersistedMemo] {
    let list = showTrash ? viewModel.trashedMemos : viewModel.filteredMemos
    guard !searchQuery.isEmpty else { return list }
    return list.filter {
      $0.title.localizedCaseInsensitiveContains(searchQuery) ||
      $0.draft.localizedCaseInsensitiveContains(searchQuery)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      toolbar
      searchBar
      Divider()
      memoList
    }
    .onAppear { viewModel.reload() }
    .sheet(isPresented: $isSessionManagerPresented) {
      SessionManagerView(
        sessions: viewModel.sessions,
        onCreate: onCreateSession,
        onRename: onRenameSession,
        onDelete: onDeleteSession
      )
    }
  }

  // MARK: - Subviews

  private var toolbar: some View {
    HStack(spacing: 8) {
      Picker("", selection: $showTrash) {
        Text("Memos").tag(false)
        Text("Trash").tag(true)
      }
      .pickerStyle(.segmented)
      .frame(width: 160)
      .onChange(of: showTrash) { _ in
        if showTrash {
          viewModel.selectedFilter = .all
        }
      }

      if viewModel.isSessionReady {
        sessionFilterPicker
          .disabled(showTrash)

        Button {
          isSessionManagerPresented = true
        } label: {
          Image(systemName: "ellipsis.circle")
            .font(.system(size: 13))
        }
        .buttonStyle(.plain)
        .foregroundStyle(showTrash ? .tertiary : .secondary)
        .disabled(showTrash)
      }

      Spacer()

      if showTrash && !viewModel.trashedMemos.isEmpty {
        Button("Empty Trash") { onEmptyTrash() }
          .foregroundStyle(.red)
          .buttonStyle(.plain)
          .font(.system(size: 12))
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  private var sessionFilterPicker: some View {
    Picker("", selection: $viewModel.selectedFilter) {
      Text("All").tag(SessionFilter.all)
      Text("Unsorted").tag(SessionFilter.unsorted)
      if !viewModel.sessions.isEmpty {
        Divider()
        ForEach(viewModel.sessions, id: \.id) { session in
          Text(session.name).tag(SessionFilter.session(session.id))
        }
      }
    }
    .pickerStyle(.menu)
    .frame(maxWidth: 120)
  }

  private var searchBar: some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
        .font(.system(size: 12))
      TextField("Search", text: $searchQuery)
        .textFieldStyle(.plain)
        .font(.system(size: 13))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color(NSColor.controlBackgroundColor))
  }

  @ViewBuilder
  private var memoList: some View {
    if displayedMemos.isEmpty {
      VStack {
        Spacer()
        Text(emptyMessage)
          .foregroundStyle(.secondary)
          .font(.system(size: 13))
        Spacer()
      }
    } else {
      List(displayedMemos, id: \.id) { memo in
        MemoRowView(
          memo: memo,
          isTrashView: showTrash,
          sessions: viewModel.sessions,
          isSessionReady: viewModel.isSessionReady,
          onOpen: { onOpenMemo(memo.id) },
          onTrash: { onTrashMemo(memo.id) },
          onRestore: { onRestoreMemo(memo.id) },
          onAssignSession: { sessionID in onAssignSession(memo.id, sessionID) }
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
      }
      .listStyle(.plain)
    }
  }

  private var emptyMessage: String {
    if !searchQuery.isEmpty { return "No results" }
    if showTrash { return "Trash is empty" }
    switch viewModel.selectedFilter {
    case .unsorted: return "No unsorted memos"
    case .session: return "No memos in this session"
    case .all: return "No memos"
    }
  }
}

// MARK: - Row

private struct MemoRowView: View {
  let memo: PersistedMemo
  let isTrashView: Bool
  let sessions: [Session]
  let isSessionReady: Bool
  let onOpen: () -> Void
  let onTrash: () -> Void
  let onRestore: () -> Void
  let onAssignSession: (UUID?) -> Void

  @State private var isHovered = false

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(memo.title.isEmpty ? "Untitled" : memo.title)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(memo.title.isEmpty ? .secondary : .primary)
          .lineLimit(1)

        if !memo.draft.isEmpty {
          Text(memo.draft)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 6) {
        Text(memo.updatedAt, style: .relative)
          .font(.system(size: 10))
          .foregroundStyle(.tertiary)

        if isTrashView {
          Button("Restore") { onRestore() }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        } else {
          Button(action: onTrash) {
            Image(systemName: "trash")
              .font(.system(size: 11))
          }
          .buttonStyle(.plain)
          .foregroundStyle(.secondary)
          .opacity(isHovered ? 1 : 0)
        }
      }
      .frame(minWidth: 60, alignment: .trailing)
    }
    .contentShape(Rectangle())
    .onTapGesture { if !isTrashView { onOpen() } }
    .onHover { isHovered = $0 }
    .contextMenu {
      if !isTrashView && isSessionReady {
        sessionAssignMenu
      }
    }
  }

  @ViewBuilder
  private var sessionAssignMenu: some View {
    Menu("Move to Session") {
      Button("Unsorted") { onAssignSession(nil) }
      if !sessions.isEmpty {
        Divider()
        ForEach(sessions, id: \.id) { session in
          Button(session.name) { onAssignSession(session.id) }
        }
      }
    }
  }
}

// MARK: - Session Manager Sheet

private struct SessionManagerView: View {
  let sessions: [Session]
  let onCreate: (String) -> Void
  let onRename: (UUID, String) -> Void
  let onDelete: (UUID) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var newSessionName = ""
  @State private var editingNames: [UUID: String] = [:]

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Sessions")
          .font(.system(size: 14, weight: .semibold))
        Spacer()
        Button("Done") { dismiss() }
          .buttonStyle(.plain)
          .foregroundStyle(.blue)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)

      Divider()

      List {
        ForEach(sessions, id: \.id) { session in
          HStack {
            TextField(
              session.name,
              text: Binding(
                get: { editingNames[session.id] ?? session.name },
                set: { editingNames[session.id] = $0 }
              )
            )
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .onSubmit { commitRename(for: session) }

            Spacer()

            Button {
              onDelete(session.id)
            } label: {
              Image(systemName: "trash")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
          }
          .padding(.vertical, 2)
          // フォーカスが外れたときに rename 確定
          .onDisappear { commitRename(for: session) }
        }

        // 新規セッション追加行
        HStack {
          Image(systemName: "plus")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
          TextField("New Session", text: $newSessionName)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .onSubmit { submitNewSession() }
        }
        .padding(.vertical, 2)
      }
      .listStyle(.plain)
    }
    .frame(width: 320, height: 360)
  }

  private func commitRename(for session: Session) {
    guard let edited = editingNames[session.id] else { return }
    let trimmed = edited.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      // 空文字は破棄して元の名前に戻す
      editingNames[session.id] = session.name
    } else if trimmed != session.name {
      onRename(session.id, trimmed)
    }
  }

  private func submitNewSession() {
    let trimmed = newSessionName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    onCreate(trimmed)
    newSessionName = ""
  }
}
