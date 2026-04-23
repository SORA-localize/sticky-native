import AppKit
import Combine
import SwiftUI

@MainActor
final class HomeWindowController: NSWindowController, NSWindowDelegate {
  let viewModel: HomeViewModel
  private let coordinator: PersistenceCoordinator
  private var cancellables: Set<AnyCancellable> = []

  var onOpenMemo: ((UUID) -> Void)?
  var onTrashMemo: ((UUID) -> Void)?
  var onRestoreMemo: ((UUID) -> Void)?
  var onEmptyTrash: (() -> Void)?

  init(coordinator: PersistenceCoordinator) {
    self.coordinator = coordinator
    self.viewModel = HomeViewModel(coordinator: coordinator)

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 720, height: 580),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = Str.allMemosWindowTitle
    window.minSize = NSSize(width: 560, height: 420)
    window.center()

    super.init(window: window)
    window.delegate = self

    NotificationCenter.default.publisher(for: .languageDidChange)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in self?.window?.title = Str.allMemosWindowTitle }
      .store(in: &cancellables)

    let rootView = HomeView(
      viewModel: viewModel,
      onOpenMemo: { [weak self] id in self?.handleOpenMemo(id: id) },
      onTrashMemo: { [weak self] id in self?.handleTrashMemo(id: id) },
      onRestoreMemo: { [weak self] id in self?.handleRestoreMemo(id: id) },
      onEmptyTrash: { [weak self] in self?.handleEmptyTrash() },
      onCreateFolder: { [weak self] name in self?.handleCreateFolder(name: name) },
      onRenameFolder: { [weak self] id, name in self?.handleRenameFolder(id: id, name: name) },
      onDeleteFolder: { [weak self] id in self?.handleDeleteFolder(id: id) },
      onAssignFolder: { [weak self] memoID, folderID in self?.handleAssignFolder(memoID: memoID, folderID: folderID) }
    )
    window.contentView = NSHostingView(rootView: rootView)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    viewModel.clearSearch()
    viewModel.reload()
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
    window?.orderFrontRegardless()
  }

  // MARK: - Memo Handlers

  private func handleOpenMemo(id: UUID) {
    onOpenMemo?(id)
  }

  private func handleTrashMemo(id: UUID) {
    onTrashMemo?(id)
    viewModel.reload()
  }

  private func handleRestoreMemo(id: UUID) {
    onRestoreMemo?(id)
    viewModel.reload()
  }

  private func handleEmptyTrash() {
    onEmptyTrash?()
    viewModel.reload()
  }

  // MARK: - Folder Handlers

  private func handleCreateFolder(name: String) {
    coordinator.createFolder(name: name)
    viewModel.reload()
  }

  private func handleRenameFolder(id: UUID, name: String) {
    coordinator.renameFolder(id: id, name: name)
    viewModel.reload()
  }

  private func handleDeleteFolder(id: UUID) {
    viewModel.deleteFolderFallbackIfNeeded(id: id)
    coordinator.deleteFolder(id: id)
    viewModel.reload()
  }

  private func handleAssignFolder(memoID: UUID, folderID: UUID?) {
    coordinator.assignFolder(memoID: memoID, folderID: folderID)
    viewModel.reload()
  }
}
