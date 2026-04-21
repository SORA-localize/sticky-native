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

  @State private var isSessionManagerPresented = false

  var body: some View {
    HStack(spacing: 0) {
      sidebar
      Divider()
      mainContent
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

  // MARK: - Sidebar

  private var sidebar: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          VStack(alignment: .leading, spacing: 3) {
            sidebarRow(.all)
            sidebarRow(.pinned)
            sidebarRow(.today)
            sidebarRow(.last7Days)
            sidebarRow(.unsorted)
            sidebarRow(.trash)
          }

          if viewModel.isSessionReady {
            VStack(alignment: .leading, spacing: 3) {
              Text("Sessions")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.top, 3)

              ForEach(viewModel.sessions, id: \.id) { session in
                sidebarRow(.session(session.id), title: session.name, icon: "folder")
              }
            }
          }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
      }

      if viewModel.isSessionReady {
        Divider()
        Button {
          isSessionManagerPresented = true
        } label: {
          Label("Sessions", systemImage: "ellipsis.circle")
            .font(.system(size: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
      }
    }
    .frame(width: 188)
    .background(Color(NSColor.controlBackgroundColor))
  }

  private func sidebarRow(_ scope: HomeScope, title: String? = nil, icon: String? = nil) -> some View {
    let selected = viewModel.selectedScope == scope
    return Button {
      viewModel.selectedScope = scope
    } label: {
      HStack(spacing: 8) {
        Image(systemName: icon ?? scope.iconName)
          .font(.system(size: 12))
          .frame(width: 16)
        Text(title ?? scope.title)
          .font(.system(size: 12))
          .lineLimit(1)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(selected ? Color.accentColor.opacity(0.18) : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .foregroundStyle(selected ? .primary : .secondary)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Main

  private var mainContent: some View {
    VStack(spacing: 0) {
      header
      searchBar
      Divider()
      memoList
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var header: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(scopeTitle)
          .font(.system(size: 16, weight: .semibold))
          .lineLimit(1)
        Text("\(memoCount) \(memoCount == 1 ? "memo" : "memos")")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }

      Spacer()

      if viewModel.selectedScope == .trash && !viewModel.trashedMemos.isEmpty {
        Button("Empty Trash") { onEmptyTrash() }
          .foregroundStyle(.red)
          .buttonStyle(.plain)
          .font(.system(size: 12))
      }
    }
    .padding(.horizontal, 18)
    .padding(.top, 14)
    .padding(.bottom, 8)
  }

  private var searchBar: some View {
    HStack(spacing: 7) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
        .font(.system(size: 12))
      TextField("Search", text: $viewModel.searchQuery)
        .textFieldStyle(.plain)
        .font(.system(size: 13))
    }
    .padding(.horizontal, 11)
    .padding(.vertical, 7)
    .background(Color(NSColor.controlBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 7))
    .padding(.horizontal, 18)
    .padding(.bottom, 10)
  }

  @ViewBuilder
  private var memoList: some View {
    if viewModel.sections.isEmpty {
      VStack {
        Spacer()
        Text(viewModel.emptyMessage)
          .foregroundStyle(.secondary)
          .font(.system(size: 13))
        Spacer()
      }
    } else {
      List {
        ForEach(viewModel.sections) { section in
          Section(section.title) {
            ForEach(section.memos, id: \.id) { memo in
              MemoRowView(
                memo: memo,
                isTrashView: viewModel.selectedScope == .trash,
                sessions: viewModel.sessions,
                sessionName: viewModel.sessionName(for: memo),
                isSessionReady: viewModel.isSessionReady,
                onOpen: { onOpenMemo(memo.id) },
                onTrash: { onTrashMemo(memo.id) },
                onRestore: { onRestoreMemo(memo.id) },
                onSetListPinned: { isPinned in viewModel.setListPinned(id: memo.id, isPinned: isPinned) },
                onAssignSession: { sessionID in onAssignSession(memo.id, sessionID) }
              )
              .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 14))
            }
          }
        }
      }
      .listStyle(.plain)
    }
  }

  private var scopeTitle: String {
    if case .session(let id) = viewModel.selectedScope,
       let session = viewModel.sessions.first(where: { $0.id == id }) {
      return session.name
    }
    return viewModel.selectedScope.title
  }

  private var memoCount: Int {
    viewModel.sections.reduce(0) { $0 + $1.memos.count }
  }
}

// MARK: - Row

private struct MemoRowView: View {
  let memo: PersistedMemo
  let isTrashView: Bool
  let sessions: [Session]
  let sessionName: String?
  let isSessionReady: Bool
  let onOpen: () -> Void
  let onTrash: () -> Void
  let onRestore: () -> Void
  let onSetListPinned: (Bool) -> Void
  let onAssignSession: (UUID?) -> Void

  @State private var isHovered = false

  private var previewText: String {
    MemoTitleFormatter.previewText(from: memo.draft)
  }

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(memo.title.isEmpty ? "Untitled" : memo.title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(memo.title.isEmpty ? .secondary : .primary)
            .lineLimit(1)

          if memo.isListPinned && !isTrashView {
            Image(systemName: "pin.fill")
              .font(.system(size: 10))
              .foregroundStyle(.secondary)
          }
        }

        if !previewText.isEmpty {
          Text(previewText)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        if let sessionName {
          Text(sessionName)
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
        }
      }

      Spacer(minLength: 8)

      VStack(alignment: .trailing, spacing: 7) {
        Text(memo.updatedAt, style: .relative)
          .font(.system(size: 10))
          .foregroundStyle(.tertiary)
          .lineLimit(1)

        if isTrashView {
          Button("Restore") { onRestore() }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        } else {
          HStack(spacing: 9) {
            Button {
              onSetListPinned(!memo.isListPinned)
            } label: {
              Image(systemName: memo.isListPinned ? "pin.fill" : "pin")
                .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(isHovered || memo.isListPinned ? 1 : 0)

            Button(action: onTrash) {
              Image(systemName: "trash")
                .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(isHovered ? 1 : 0)
          }
        }
      }
      .frame(minWidth: 76, alignment: .trailing)
    }
    .contentShape(Rectangle())
    .onTapGesture { if !isTrashView { onOpen() } }
    .onHover { isHovered = $0 }
    .contextMenu {
      if isTrashView {
        Button("Restore") { onRestore() }
      } else {
        Button(memo.isListPinned ? "Unpin from List" : "Pin in List") {
          onSetListPinned(!memo.isListPinned)
        }

        if isSessionReady {
          Divider()
          sessionAssignMenu
        }

        Divider()
        Button("Move to Trash") { onTrash() }
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

// MARK: - Sidebar Metadata

private extension HomeScope {
  var title: String {
    switch self {
    case .all:
      return "All Memos"
    case .pinned:
      return "Pinned"
    case .today:
      return "Today"
    case .last7Days:
      return "Last 7 Days"
    case .unsorted:
      return "Unsorted"
    case .trash:
      return "Trash"
    case .session:
      return "Session"
    }
  }

  var iconName: String {
    switch self {
    case .all:
      return "tray.full"
    case .pinned:
      return "pin"
    case .today:
      return "sun.max"
    case .last7Days:
      return "calendar"
    case .unsorted:
      return "tray"
    case .trash:
      return "trash"
    case .session:
      return "folder"
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
          .onDisappear { commitRename(for: session) }
        }

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

