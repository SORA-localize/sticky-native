import SwiftUI

private extension View {
  @ViewBuilder
  func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
    if condition { transform(self) } else { self }
  }
}

struct HomeView: View {
  @ObservedObject var viewModel: HomeViewModel
  let onOpenMemo: (UUID) -> Void
  let onTrashMemo: (UUID) -> Void
  let onRestoreMemo: (UUID) -> Void
  let onEmptyTrash: () -> Void
  let onCreateFolder: (String) -> Void
  let onRenameFolder: (UUID, String) -> Void
  let onDeleteFolder: (UUID) -> Void
  let onAssignFolder: (UUID, UUID?) -> Void

  @State private var isFolderManagerPresented = false
  @State private var isSidebarVisible = true

  var body: some View {
    HStack(spacing: 0) {
      if isSidebarVisible {
        sidebar
        Divider()
      }
      mainContent
    }
    .onAppear { viewModel.reload() }
    .sheet(isPresented: $isFolderManagerPresented) {
      FolderManagerView(
        folders: viewModel.folders,
        onCreate: onCreateFolder,
        onRename: onRenameFolder,
        onDelete: onDeleteFolder
      )
    }
  }

  // MARK: - Sidebar

  private var sidebarToggleButton: some View {
    Button {
      isSidebarVisible.toggle()
    } label: {
      Image(systemName: "sidebar.left")
        .font(.system(size: 13))
        .frame(width: 24, height: 24)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .foregroundStyle(.secondary)
    .help(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar")
  }

  private var sidebar: some View {
    VStack(spacing: 0) {
      HStack {
        Spacer()
        sidebarToggleButton
      }
      .padding(.horizontal, 12)
      .padding(.top, 10)
      .padding(.bottom, 4)

      ScrollView {
        VStack(alignment: .leading, spacing: 3) {
          sidebarRow(scope: .all, title: "All Memos", icon: "tray.full", count: viewModel.allMemosCount)

          if viewModel.isFolderReady && !viewModel.folders.isEmpty {
            ForEach(viewModel.folders, id: \.id) { folder in
              folderSidebarRow(folder: folder)
            }
          }

          Divider()
            .padding(.vertical, 4)

          sidebarRow(scope: .trash, title: "Trash", icon: "trash", count: viewModel.trashCount)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      if viewModel.isFolderReady {
        Divider()
        Button {
          isFolderManagerPresented = true
        } label: {
          Label("New Folder", systemImage: "folder.badge.plus")
            .font(.system(size: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
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

  private func sidebarRow(scope: HomeScope, title: String, icon: String, count: Int) -> some View {
    SidebarRowView(
      scope: scope,
      title: title,
      icon: icon,
      count: count,
      isSelected: viewModel.selectedScope == scope,
      onSelect: { viewModel.selectedScope = scope },
      onDrop: nil
    )
  }

  private func folderSidebarRow(folder: Folder) -> some View {
    SidebarRowView(
      scope: .folder(folder.id),
      title: folder.name,
      icon: "folder",
      count: viewModel.folderCount(id: folder.id),
      isSelected: viewModel.selectedScope == .folder(folder.id),
      onSelect: { viewModel.selectedScope = .folder(folder.id) },
      onDrop: { memoID in onAssignFolder(memoID, folder.id) }
    )
  }

  // MARK: - Main

  private var mainContent: some View {
    VStack(spacing: 0) {
      header
      Divider()
      memoList
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var header: some View {
    HStack(spacing: 12) {
      if !isSidebarVisible {
        sidebarToggleButton
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(scopeTitle)
          .font(.system(size: 16, weight: .semibold))
          .lineLimit(1)
        Text("\(memoCount) \(memoCount == 1 ? "memo" : "memos")")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }

      Spacer()

      HStack(spacing: 7) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
          .font(.system(size: 12))
        TextField("Search", text: $viewModel.searchQuery)
          .textFieldStyle(.plain)
          .font(.system(size: 13))
          .frame(width: 160)
      }
      .padding(.horizontal, 9)
      .padding(.vertical, 6)
      .background(Color(NSColor.controlBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 7))

      if viewModel.selectedScope == .trash && !viewModel.trashedMemos.isEmpty {
        Button("Empty Trash") { onEmptyTrash() }
          .foregroundStyle(.red)
          .buttonStyle(.plain)
          .font(.system(size: 12))
      }
    }
    .padding(.horizontal, 18)
    .padding(.top, 14)
    .padding(.bottom, 12)
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
          Text(section.title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 12, leading: 18, bottom: 2, trailing: 18))

          ForEach(section.memos, id: \.id) { memo in
            MemoRowView(
              memo: memo,
              isTrashView: viewModel.selectedScope == .trash,
              folders: viewModel.folders,
              isFolderReady: viewModel.isFolderReady,
              onOpen: { onOpenMemo(memo.id) },
              onTrash: { onTrashMemo(memo.id) },
              onRestore: { onRestoreMemo(memo.id) },
              onSetListPinned: { isPinned in viewModel.setListPinned(id: memo.id, isPinned: isPinned) },
              onAssignFolder: { folderID in onAssignFolder(memo.id, folderID) }
            )
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 14))
          }
        }
      }
      .listStyle(.plain)
    }
  }

  private var scopeTitle: String {
    if case .folder(let id) = viewModel.selectedScope,
       let folder = viewModel.folders.first(where: { $0.id == id }) {
      return folder.name
    }
    switch viewModel.selectedScope {
    case .all: return "All Memos"
    case .trash: return "Trash"
    case .folder: return "Folder"
    }
  }

  private var memoCount: Int {
    viewModel.sections.reduce(0) { $0 + $1.memos.count }
  }
}

// MARK: - Row

private struct MemoRowView: View {
  let memo: PersistedMemo
  let isTrashView: Bool
  let folders: [Folder]
  let isFolderReady: Bool
  let onOpen: () -> Void
  let onTrash: () -> Void
  let onRestore: () -> Void
  let onSetListPinned: (Bool) -> Void
  let onAssignFolder: (UUID?) -> Void

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
      }

      Spacer(minLength: 8)

      VStack(alignment: .trailing, spacing: 7) {
        Text(formattedDate(memo.contentEditedAt))
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
    .if(!isTrashView) { $0.draggable(MemoTransferItem(id: memo.id)) }
    .contextMenu {
      if isTrashView {
        Button("Restore") { onRestore() }
      } else {
        Button(memo.isListPinned ? "Unpin from List" : "Pin in List") {
          onSetListPinned(!memo.isListPinned)
        }

        if isFolderReady {
          Divider()
          folderAssignMenu
        }

        Divider()
        Button("Move to Trash") { onTrash() }
      }
    }
  }

  @ViewBuilder
  private var folderAssignMenu: some View {
    if memo.sessionID != nil {
      Button("Remove from Folder") { onAssignFolder(nil) }
    }
    if !folders.isEmpty {
      Menu("Move to Folder") {
        ForEach(folders, id: \.id) { folder in
          Button(folder.name) { onAssignFolder(folder.id) }
        }
      }
    }
  }

  private func formattedDate(_ date: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(date) {
      return date.formatted(.dateTime.hour().minute())
    }
    let days = cal.dateComponents(
      [.day],
      from: cal.startOfDay(for: date),
      to: cal.startOfDay(for: Date())
    ).day ?? 0
    if days <= 7 {
      return date.formatted(.dateTime.weekday(.wide))
    }
    if cal.isDate(date, equalTo: Date(), toGranularity: .year) {
      return date.formatted(.dateTime.month(.wide).day())
    }
    return date.formatted(.dateTime.year().month(.defaultDigits).day())
  }
}

// MARK: - Sidebar Row

private struct SidebarRowView: View {
  let scope: HomeScope
  let title: String
  let icon: String
  let count: Int
  let isSelected: Bool
  let onSelect: () -> Void
  let onDrop: ((UUID) -> Void)?

  @State private var isDropTargeted = false

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 8) {
        Image(systemName: icon)
          .font(.system(size: 12))
          .frame(width: 16)
        Text(title)
          .font(.system(size: 12))
          .lineLimit(1)
        Spacer(minLength: 0)
        if count > 0 {
          Text("\(count)")
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
      .contentShape(Rectangle())
      .background((isSelected || isDropTargeted) ? Color.accentColor.opacity(0.18) : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .foregroundStyle(isSelected ? .primary : .secondary)
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity, alignment: .leading)
    .if(onDrop != nil) { view in
      view.dropDestination(for: MemoTransferItem.self) { items, _ in
        guard let item = items.first else { return false }
        onDrop?(item.id)
        return true
      } isTargeted: { targeted in
        isDropTargeted = targeted
      }
    }
  }
}

// MARK: - Folder Manager Sheet

private struct FolderManagerView: View {
  let folders: [Folder]
  let onCreate: (String) -> Void
  let onRename: (UUID, String) -> Void
  let onDelete: (UUID) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var newFolderName = ""
  @State private var editingNames: [UUID: String] = [:]

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Folders")
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
        ForEach(folders, id: \.id) { folder in
          HStack {
            TextField(
              folder.name,
              text: Binding(
                get: { editingNames[folder.id] ?? folder.name },
                set: { editingNames[folder.id] = $0 }
              )
            )
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .onSubmit { commitRename(for: folder) }

            Spacer()

            Button {
              onDelete(folder.id)
            } label: {
              Image(systemName: "trash")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
          }
          .padding(.vertical, 2)
          .onDisappear { commitRename(for: folder) }
        }

        HStack {
          Image(systemName: "plus")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
          TextField("New Folder", text: $newFolderName)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .onSubmit { submitNewFolder() }
        }
        .padding(.vertical, 2)
      }
      .listStyle(.plain)
    }
    .frame(width: 320, height: 360)
  }

  private func commitRename(for folder: Folder) {
    guard let edited = editingNames[folder.id] else { return }
    let trimmed = edited.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      editingNames[folder.id] = folder.name
    } else if trimmed != folder.name {
      onRename(folder.id, trimmed)
    }
  }

  private func submitNewFolder() {
    let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    onCreate(trimmed)
    newFolderName = ""
  }
}
