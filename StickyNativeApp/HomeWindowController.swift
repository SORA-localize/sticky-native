import AppKit
import SwiftUI

@MainActor
final class HomeWindowController: NSWindowController, NSWindowDelegate {
  let viewModel: HomeViewModel
  private let coordinator: PersistenceCoordinator

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
    window.title = "All Memos"
    window.minSize = NSSize(width: 560, height: 420)
    window.center()

    super.init(window: window)
    window.delegate = self

    let rootView = HomeView(
      viewModel: viewModel,
      onOpenMemo: { [weak self] id in self?.handleOpenMemo(id: id) },
      onTrashMemo: { [weak self] id in self?.handleTrashMemo(id: id) },
      onRestoreMemo: { [weak self] id in self?.handleRestoreMemo(id: id) },
      onEmptyTrash: { [weak self] in self?.handleEmptyTrash() },
      onCreateSession: { [weak self] name in self?.handleCreateSession(name: name) },
      onRenameSession: { [weak self] id, name in self?.handleRenameSession(id: id, name: name) },
      onDeleteSession: { [weak self] id in self?.handleDeleteSession(id: id) },
      onAssignSession: { [weak self] memoID, sessionID in self?.handleAssignSession(memoID: memoID, sessionID: sessionID) }
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

  // MARK: - Session Handlers

  private func handleCreateSession(name: String) {
    coordinator.createSession(name: name)
    viewModel.reload()
  }

  private func handleRenameSession(id: UUID, name: String) {
    coordinator.renameSession(id: id, name: name)
    viewModel.reload()
  }

  private func handleDeleteSession(id: UUID) {
    viewModel.deleteSessionFallbackIfNeeded(id: id)
    coordinator.deleteSession(id: id)
    viewModel.reload()
  }

  private func handleAssignSession(memoID: UUID, sessionID: UUID?) {
    coordinator.assignSession(memoID: memoID, sessionID: sessionID)
    viewModel.reload()
  }
}
