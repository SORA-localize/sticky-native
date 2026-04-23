import SwiftUI

private extension View {
  @ViewBuilder
  func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
    if condition { transform(self) } else { self }
  }
}

struct HomeView: View {
  @StateObject private var settings = AppSettings.shared
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
  @State private var pendingDeleteFolder: Folder?
  @State private var editingSidebarFolderID: UUID?
  @State private var editingSidebarFolderName = ""

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
        onDeleteConfirmed: onDeleteFolder
      )
    }
    .alert(
      Str.deleteFolderAlertTitle,
      isPresented: Binding(
        get: { pendingDeleteFolder != nil },
        set: { if !$0 { pendingDeleteFolder = nil } }
      )
    ) {
      Button(Str.delete, role: .destructive) {
        confirmSidebarFolderDelete()
      }
      Button(Str.trashAlertCancel, role: .cancel) {
        pendingDeleteFolder = nil
      }
    } message: {
      Text(Str.deleteFolderAlertMessage)
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
    .help(isSidebarVisible ? Str.hideSidebar : Str.showSidebar)
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
          sidebarRow(scope: .all, title: Str.allMemos, icon: "tray.full", count: viewModel.allMemosCount)

          if viewModel.isFolderReady && !viewModel.folders.isEmpty {
            ForEach(viewModel.folders, id: \.id) { folder in
              folderSidebarRow(folder: folder)
            }
          }

          Divider()
            .padding(.vertical, 4)

          sidebarRow(scope: .trash, title: Str.trash, icon: "trash", count: viewModel.trashCount)
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
          Label(Str.folderManagement, systemImage: "folder.badge.plus")
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
      onDrop: scope == .all ? { memoID in
        moveMemoToAllMemosIfNeeded(memoID: memoID)
      } : nil
    )
  }

  private func folderSidebarRow(folder: Folder) -> some View {
    FolderSidebarRowView(
      folder: folder,
      count: viewModel.folderCount(id: folder.id),
      isSelected: viewModel.selectedScope == .folder(folder.id),
      isEditing: editingSidebarFolderID == folder.id,
      editingName: editingSidebarFolderName,
      onSelect: {
        guard editingSidebarFolderID == nil else { return }
        viewModel.selectedScope = .folder(folder.id)
      },
      onBeginEditing: { beginSidebarRename(folder: folder) },
      onEditingNameChange: { editingSidebarFolderName = $0 },
      onCommitEditing: { commitSidebarRename() },
      onRequestDelete: { pendingDeleteFolder = $0 },
      onDrop: { memoID in
        onAssignFolder(memoID, folder.id)
        return true
      }
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
        Text("\(memoCount) \(memoCount == 1 ? Str.memoSingular : Str.memoPlural)")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }

      Spacer()

      HStack(spacing: 7) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
          .font(.system(size: 12))
        TextField(Str.search, text: $viewModel.searchQuery)
          .textFieldStyle(.plain)
          .font(.system(size: 13))
          .frame(width: 160)
      }
      .padding(.horizontal, 9)
      .padding(.vertical, 6)
      .background(Color(NSColor.controlBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 7))

      if viewModel.selectedScope == .trash && !viewModel.trashedMemos.isEmpty {
        Button(Str.emptyTrash) { onEmptyTrash() }
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
    case .all: return Str.allMemos
    case .trash: return Str.trash
    case .folder: return Str.folderLabel
    }
  }

  private var memoCount: Int {
    viewModel.sections.reduce(0) { $0 + $1.memos.count }
  }

  private func beginSidebarRename(folder: Folder) {
    editingSidebarFolderID = folder.id
    editingSidebarFolderName = folder.name
  }

  private func commitSidebarRename() {
    guard let id = editingSidebarFolderID else { return }
    let edited = editingSidebarFolderName
    editingSidebarFolderID = nil
    editingSidebarFolderName = ""

    guard let folder = viewModel.folders.first(where: { $0.id == id }) else { return }
    let trimmed = edited.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed != folder.name else { return }
    onRenameFolder(id, trimmed)
  }

  private func confirmSidebarFolderDelete() {
    guard let folder = pendingDeleteFolder else { return }
    pendingDeleteFolder = nil
    onDeleteFolder(folder.id)
  }

  private func moveMemoToAllMemosIfNeeded(memoID: UUID) -> Bool {
    guard let memo = viewModel.memos.first(where: { $0.id == memoID }),
          memo.sessionID != nil else {
      return false
    }
    onAssignFolder(memoID, nil)
    return true
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
      dragSurface
      actionSurface
    }
    .onHover { isHovered = $0 }
    .contextMenu {
      if isTrashView {
        Button(Str.restore) { onRestore() }
      } else {
        Button(memo.isListPinned ? Str.unpinFromList : Str.pinInList) {
          onSetListPinned(!memo.isListPinned)
        }

        if isFolderReady {
          Divider()
          folderAssignMenu
        }

        Divider()
        Button(Str.moveToTrash) { onTrash() }
      }
    }
  }

  private var memoSummary: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 6) {
        Text(memo.title.isEmpty ? Str.untitled : memo.title)
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
  }

  private var dragSurfaceLabel: some View {
    HStack(alignment: .center, spacing: 10) {
      memoSummary

      Spacer(minLength: 8)

      Text(formattedDate(memo.contentEditedAt))
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
  }

  @ViewBuilder
  private var dragSurface: some View {
    if isTrashView {
      dragSurfaceLabel
    } else {
      Button(action: onOpen) {
        dragSurfaceLabel
      }
      .buttonStyle(.plain)
      .draggable(MemoTransferItem(id: memo.id))
    }
  }

  @ViewBuilder
  private var actionSurface: some View {
    if isTrashView {
      Button(Str.restore) { onRestore() }
        .font(.system(size: 11))
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
        .frame(minWidth: 54, alignment: .trailing)
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
      .frame(minWidth: 44, alignment: .trailing)
    }
  }

  @ViewBuilder
  private var folderAssignMenu: some View {
    if memo.sessionID != nil {
      Button(Str.removeFromFolder) { onAssignFolder(nil) }
    }
    if !folders.isEmpty {
      Menu(Str.moveToFolder) {
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
  let onDrop: ((UUID) -> Bool)?

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
        return onDrop?(item.id) ?? false
      } isTargeted: { targeted in
        isDropTargeted = targeted
      }
    }
  }
}

private struct FolderSidebarRowView: View {
  let folder: Folder
  let count: Int
  let isSelected: Bool
  let isEditing: Bool
  let editingName: String
  let onSelect: () -> Void
  let onBeginEditing: () -> Void
  let onEditingNameChange: (String) -> Void
  let onCommitEditing: () -> Void
  let onRequestDelete: (Folder) -> Void
  let onDrop: (UUID) -> Bool

  @FocusState private var isNameFieldFocused: Bool
  @State private var isDropTargeted = false

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "folder")
        .font(.system(size: 12))
        .frame(width: 16)

      nameContent

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
    .onTapGesture {
      if !isEditing {
        onSelect()
      }
    }
    .contextMenu {
      Button(Str.delete, role: .destructive) {
        onRequestDelete(folder)
      }
    }
    .dropDestination(for: MemoTransferItem.self) { items, _ in
      guard let item = items.first else { return false }
      return onDrop(item.id)
    } isTargeted: { targeted in
      isDropTargeted = targeted
    }
    .onChange(of: isEditing) { _, editing in
      if editing {
        DispatchQueue.main.async {
          isNameFieldFocused = true
        }
      }
    }
    .onAppear {
      if isEditing {
        DispatchQueue.main.async {
          isNameFieldFocused = true
        }
      }
    }
  }

  @ViewBuilder
  private var nameContent: some View {
    if isEditing {
      TextField("", text: Binding(
        get: { editingName },
        set: onEditingNameChange
      ))
      .textFieldStyle(.plain)
      .font(.system(size: 12))
      .focused($isNameFieldFocused)
      .onSubmit { onCommitEditing() }
      .onChange(of: isNameFieldFocused) { _, focused in
        if !focused {
          onCommitEditing()
        }
      }
    } else {
      Text(folder.name)
        .font(.system(size: 12))
        .lineLimit(1)
        .onTapGesture(count: 2) {
          onBeginEditing()
        }
    }
  }
}

// MARK: - Folder Manager Sheet

private struct FolderManagerView: View {
  let folders: [Folder]
  let onCreate: (String) -> Void
  let onRename: (UUID, String) -> Void
  let onDeleteConfirmed: (UUID) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var newFolderName = ""
  @State private var editingNames: [UUID: String] = [:]
  @State private var pendingDeleteFolderInSheet: Folder?

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(Str.folders)
          .font(.system(size: 14, weight: .semibold))
        Spacer()
        Button(Str.done) { dismiss() }
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
              pendingDeleteFolderInSheet = folder
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
          TextField(Str.newFolder, text: $newFolderName)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .onSubmit { submitNewFolder() }
        }
        .padding(.vertical, 2)
      }
      .listStyle(.plain)
    }
    .frame(width: 320, height: 360)
    .alert(
      Str.deleteFolderAlertTitle,
      isPresented: Binding(
        get: { pendingDeleteFolderInSheet != nil },
        set: { if !$0 { pendingDeleteFolderInSheet = nil } }
      )
    ) {
      Button(Str.delete, role: .destructive) {
        confirmDelete()
      }
      Button(Str.trashAlertCancel, role: .cancel) {
        pendingDeleteFolderInSheet = nil
      }
    } message: {
      Text(Str.deleteFolderAlertMessage)
    }
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

  private func confirmDelete() {
    guard let folder = pendingDeleteFolderInSheet else { return }
    pendingDeleteFolderInSheet = nil
    onDeleteConfirmed(folder.id)
  }
}
