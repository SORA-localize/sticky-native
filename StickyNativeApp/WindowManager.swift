import Foundation

@MainActor
final class WindowManager {
  private let cascadeStep = NSSize(width: 28, height: 24)
  private var openControllers: [UUID: MemoWindowController] = [:]
  private var closedMemoIDs: [UUID] = []
  private var lastCascadeOrigin: NSPoint?

  var onClosedStackChanged: (() -> Void)?

  var canReopenClosedMemo: Bool {
    !closedMemoIDs.isEmpty
  }

  func createNewMemoWindow() {
    let memo = MemoWindow()
    let controller = makeController(for: memo)
    openControllers[memo.id] = controller
    controller.showAndFocusEditor()
    lastCascadeOrigin = controller.currentFrame?.origin
  }

  func reopenLastClosedMemo() {
    guard let memoID = closedMemoIDs.popLast() else {
      return
    }

    let memo = MemoWindow(id: memoID)
    let controller = makeController(for: memo)
    openControllers[memo.id] = controller
    controller.showAndFocusEditor()
    lastCascadeOrigin = controller.currentFrame?.origin
    onClosedStackChanged?()
  }

  private func makeController(for memo: MemoWindow) -> MemoWindowController {
    let nextOrigin = makeNextWindowOrigin()

    return MemoWindowController(memo: memo, origin: nextOrigin) { [weak self] memoID in
      self?.handleWindowClose(memoID: memoID)
    }
  }

  private func handleWindowClose(memoID: UUID) {
    openControllers.removeValue(forKey: memoID)
    closedMemoIDs.removeAll { $0 == memoID }
    closedMemoIDs.append(memoID)
    onClosedStackChanged?()
  }

  private func makeNextWindowOrigin() -> NSPoint? {
    guard let lastCascadeOrigin else {
      return nil
    }

    return NSPoint(
      x: lastCascadeOrigin.x + cascadeStep.width,
      y: lastCascadeOrigin.y - cascadeStep.height
    )
  }
}
