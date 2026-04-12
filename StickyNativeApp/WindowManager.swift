import Foundation

struct ClosedMemoRecord {
  let memoID: UUID
  let origin: NSPoint?
  let isPinned: Bool
}

@MainActor
final class WindowManager {
  private let cascadeStep = NSSize(width: 28, height: 24)
  private var openControllers: [UUID: MemoWindowController] = [:]
  private var closedMemoRecords: [ClosedMemoRecord] = []
  private var lastCascadeOrigin: NSPoint?

  var onClosedStackChanged: (() -> Void)?

  var canReopenClosedMemo: Bool {
    !closedMemoRecords.isEmpty
  }

  func createNewMemoWindow() {
    let memo = MemoWindow()
    let controller = makeController(for: memo)
    openControllers[memo.id] = controller
    controller.showAndFocusEditor()
    lastCascadeOrigin = controller.currentFrame?.origin
  }

  func reopenLastClosedMemo() {
    guard let record = closedMemoRecords.popLast() else {
      return
    }

    let memo = MemoWindow(id: record.memoID)
    let controller = makeController(for: memo, origin: record.origin, initiallyPinned: record.isPinned)
    openControllers[memo.id] = controller
    controller.showAndFocusEditor()
    lastCascadeOrigin = controller.currentFrame?.origin
    onClosedStackChanged?()
  }

  private func makeController(
    for memo: MemoWindow,
    origin: NSPoint? = nil,
    initiallyPinned: Bool = false
  ) -> MemoWindowController {
    let resolvedOrigin = origin ?? makeNextWindowOrigin()

    return MemoWindowController(
      memo: memo,
      origin: resolvedOrigin,
      initiallyPinned: initiallyPinned
    ) { [weak self] record in
      self?.handleWindowClose(record: record)
    }
  }

  private func handleWindowClose(record: ClosedMemoRecord) {
    openControllers.removeValue(forKey: record.memoID)
    closedMemoRecords.removeAll { $0.memoID == record.memoID }
    closedMemoRecords.append(record)
    lastCascadeOrigin = record.origin ?? lastCascadeOrigin
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
