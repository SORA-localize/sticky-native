import AppKit
import SwiftUI

@MainActor
final class HomeWindowController: NSWindowController, NSWindowDelegate {
  let viewModel: HomeViewModel

  var onOpenMemo: ((UUID) -> Void)?
  var onTrashMemo: ((UUID) -> Void)?
  var onRestoreMemo: ((UUID) -> Void)?
  var onEmptyTrash: (() -> Void)?

  init(coordinator: PersistenceCoordinator) {
    self.viewModel = HomeViewModel(coordinator: coordinator)

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 480, height: 580),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = "All Memos"
    window.minSize = NSSize(width: 360, height: 400)
    window.center()

    super.init(window: window)
    window.delegate = self

    let rootView = HomeView(
      viewModel: viewModel,
      onOpenMemo: { [weak self] id in self?.handleOpenMemo(id: id) },
      onTrashMemo: { [weak self] id in self?.handleTrashMemo(id: id) },
      onRestoreMemo: { [weak self] id in self?.handleRestoreMemo(id: id) },
      onEmptyTrash: { [weak self] in self?.handleEmptyTrash() }
    )
    window.contentView = NSHostingView(rootView: rootView)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    viewModel.reload()
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
    window?.orderFrontRegardless()
  }

  // MARK: - Handlers

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
}
