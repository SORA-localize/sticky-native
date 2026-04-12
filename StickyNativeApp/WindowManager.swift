import Foundation

@MainActor
final class WindowManager {
  private var openControllers: [UUID: MemoWindowController] = [:]
  private var closedMemoIDs: [UUID] = []

  var onClosedStackChanged: (() -> Void)?

  var canReopenClosedMemo: Bool {
    !closedMemoIDs.isEmpty
  }

  func createNewMemoWindow() {
    let memo = MemoWindow()
    let controller = makeController(for: memo)
    openControllers[memo.id] = controller
    controller.showAndFocusEditor()
  }

  func reopenLastClosedMemo() {
    guard let memoID = closedMemoIDs.popLast() else {
      return
    }

    let memo = MemoWindow(id: memoID)
    let controller = makeController(for: memo)
    openControllers[memo.id] = controller
    controller.showAndFocusEditor()
    onClosedStackChanged?()
  }

  private func makeController(for memo: MemoWindow) -> MemoWindowController {
    MemoWindowController(memo: memo) { [weak self] memoID in
      self?.handleWindowClose(memoID: memoID)
    }
  }

  private func handleWindowClose(memoID: UUID) {
    openControllers.removeValue(forKey: memoID)
    closedMemoIDs.removeAll { $0 == memoID }
    closedMemoIDs.append(memoID)
    onClosedStackChanged?()
  }
}
