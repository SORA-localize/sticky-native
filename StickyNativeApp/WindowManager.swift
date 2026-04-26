import AppKit

struct ClosedMemoRecord {
  let memoID: UUID
  let frame: NSRect?
  var isAutoDelete: Bool = false
}

@MainActor
final class WindowManager {
  private let cascadeStep = NSSize(width: 28, height: 24)
  private var openControllers: [UUID: MemoWindowController] = [:]
  private var closedMemoRecords: [ClosedMemoRecord] = []
  private var lastCascadeOrigin: NSPoint?

  private let coordinator: PersistenceCoordinator
  private let appSettings: AppSettings
  private lazy var scheduler = AutosaveScheduler { [weak self] id, content in
    self?.persistContent(id: id, content: content)
  }

  var onClosedStackChanged: (() -> Void)?
  private var isTerminating = false
  private var trashedMemoIDs: Set<UUID> = []

  init(coordinator: PersistenceCoordinator, appSettings: AppSettings) {
    self.coordinator = coordinator
    self.appSettings = appSettings
  }

  var canReopenClosedMemo: Bool {
    !closedMemoRecords.isEmpty
  }

  func openMemo(id: UUID) {
    if let controller = openControllers[id] {
      controller.showAndFocusEditor()
      return
    }
    closedMemoRecords.removeAll { $0.memoID == id }
    guard let persisted = coordinator.fetchMemo(id: id) else { return }
    let savedFrame = frame(from: persisted)
    let displayContent = EditorContentFactory.makeDisplayContent(
      draft: persisted.draft,
      richTextData: persisted.richTextData
    )
    coordinator.markOpen(id: id)
    let memo = MemoWindow(
      id: id,
      draft: persisted.draft,
      attributedContent: displayContent.attributedString,
      colorTheme: MemoColorTheme.from(index: persisted.colorIndex)
    )
    let controller = makeController(for: memo, savedFrame: savedFrame, initiallyPinned: persisted.isPinned)
    openControllers[id] = controller
    controller.showAndFocusEditor()
    if let frame = controller.currentFrame {
      controller.window?.setFrame(clampedFrame(frame), display: false)
    }
    lastCascadeOrigin = controller.currentFrame?.origin
    onClosedStackChanged?()
  }

  func trashMemo(id: UUID) {
    if openControllers[id] != nil {
      trashedMemoIDs.insert(id)
      openControllers[id]?.window?.close()
    } else {
      closedMemoRecords.removeAll { $0.memoID == id }
      coordinator.trashMemo(id: id)
      onClosedStackChanged?()
    }
  }

  func restoreMemo(id: UUID) {
    coordinator.restoreMemo(id: id)
  }

  func emptyTrash() {
    coordinator.emptyTrash()
  }

  func restorePersistedOpenMemos() {
    let memos = coordinator.fetchOpenMemos()
    for persisted in memos {
      if MemoWindowController.isDraftEmpty(persisted.draft) {
        coordinator.permanentDelete(id: persisted.id)
        continue
      }
      let savedFrame = frame(from: persisted)
      let displayContent = EditorContentFactory.makeDisplayContent(
        draft: persisted.draft,
        richTextData: persisted.richTextData
      )
      let memo = MemoWindow(
        id: persisted.id,
        draft: persisted.draft,
        attributedContent: displayContent.attributedString,
        colorTheme: MemoColorTheme.from(index: persisted.colorIndex)
      )
      let controller = makeController(for: memo, savedFrame: savedFrame, initiallyPinned: persisted.isPinned)
      openControllers[memo.id] = controller
      controller.showAndFocusEditor()
      if let frame = controller.currentFrame {
        controller.window?.setFrame(clampedFrame(frame), display: false)
      }
      lastCascadeOrigin = controller.currentFrame?.origin
    }
  }

  func prepareForTermination() {
    isTerminating = true
    for (_, controller) in openControllers {
      if MemoWindowController.isDraftEmpty(controller.memo.draft) {
        coordinator.permanentDelete(id: controller.memo.id)
      } else {
        scheduler.flush(id: controller.memo.id, content: EditorContent(attributedString: controller.memo.attributedContent))
        coordinator.saveWindowState(id: controller.memo.id, frame: controller.currentFrame, isOpen: true)
      }
    }
  }

  func createNewMemoWindow() {
    let memo = MemoWindow(colorTheme: appSettings.makeNewMemoColorTheme())
    let size = NSSize(width: appSettings.defaultMemoWidth, height: appSettings.defaultMemoHeight)
    let controller = makeController(for: memo, contentSize: size)
    openControllers[memo.id] = controller
    controller.showAndFocusEditor()
    lastCascadeOrigin = controller.currentFrame?.origin
    coordinator.saveMemoContent(id: memo.id, content: EditorContent(plainText: ""), colorIndex: memo.colorTheme.colorIndex)
    onClosedStackChanged?()
  }

  func reopenLastClosedMemo() {
    guard let record = closedMemoRecords.popLast() else {
      return
    }

    let persisted = coordinator.fetchMemo(id: record.memoID)
    let draft = persisted?.draft ?? ""
    let displayContent = EditorContentFactory.makeDisplayContent(
      draft: draft,
      richTextData: persisted?.richTextData
    )
    let savedFrame = record.frame ?? persisted.flatMap { frame(from: $0) }
    let contentSize = savedFrame == nil ? Self.defaultContentSize(from: appSettings) : nil
    let isPinned = persisted?.isPinned ?? false

    coordinator.markOpen(id: record.memoID)
    let memo = MemoWindow(
      id: record.memoID,
      draft: draft,
      attributedContent: displayContent.attributedString,
      colorTheme: MemoColorTheme.from(index: persisted?.colorIndex ?? MemoColorTheme.fallback.colorIndex)
    )
    let controller = makeController(for: memo, contentSize: contentSize, savedFrame: savedFrame, initiallyPinned: isPinned)
    openControllers[memo.id] = controller
    controller.showAndFocusEditor()
    lastCascadeOrigin = controller.currentFrame?.origin
    onClosedStackChanged?()
  }

  private func makeController(
    for memo: MemoWindow,
    origin: NSPoint? = nil,
    contentSize: NSSize? = nil,
    savedFrame: NSRect? = nil,
    initiallyPinned: Bool = false
  ) -> MemoWindowController {
    let resolvedOrigin = savedFrame == nil ? (origin ?? makeNextWindowOrigin()) : nil

    return MemoWindowController(
      memo: memo,
      origin: resolvedOrigin,
      contentSize: contentSize,
      savedFrame: savedFrame,
      initiallyPinned: initiallyPinned,
      appSettings: appSettings,
      onDraftChange: { [weak self] id, content in
        self?.scheduler.schedule(id: id, content: content)
      },
      onFlush: { [weak self] id, content in
        self?.scheduler.flush(id: id, content: content)
      },
      onPinChange: { [weak self] id, isPinned in
        self?.coordinator.savePinned(id: id, isPinned: isPinned)
      },
      onTrash: { [weak self] id in
        self?.trashMemo(id: id)
      },
      onClose: { [weak self] record in
        self?.handleWindowClose(record: record)
      }
    )
  }

  private func handleWindowClose(record: ClosedMemoRecord) {
    openControllers.removeValue(forKey: record.memoID)

    if record.isAutoDelete {
      coordinator.permanentDelete(id: record.memoID)
    } else if trashedMemoIDs.contains(record.memoID) {
      trashedMemoIDs.remove(record.memoID)
      closedMemoRecords.removeAll { $0.memoID == record.memoID }
      coordinator.trashMemo(id: record.memoID)
    } else {
      closedMemoRecords.removeAll { $0.memoID == record.memoID }
      closedMemoRecords.append(record)
      lastCascadeOrigin = record.frame?.origin ?? lastCascadeOrigin
      if !isTerminating {
        coordinator.saveWindowState(id: record.memoID, frame: record.frame, isOpen: false)
      }
    }

    onClosedStackChanged?()
  }

  private func clampedFrame(_ frame: NSRect) -> NSRect {
    let screens = NSScreen.screens
    guard !screens.isEmpty else { return frame }

    // frame の左上コーナーが最も近いスクリーンを探す
    let topLeft = NSPoint(x: frame.minX, y: frame.maxY)
    let nearest = screens.min(by: {
      let d0 = hypot($0.visibleFrame.midX - topLeft.x, $0.visibleFrame.midY - topLeft.y)
      let d1 = hypot($1.visibleFrame.midX - topLeft.x, $1.visibleFrame.midY - topLeft.y)
      return d0 < d1
    }) ?? screens[0]

    let visible = nearest.visibleFrame
    let margin: CGFloat = 20

    // origin を visible frame 内に収まるよう補正（サイズは変更しない）
    let clampedX = min(max(frame.minX, visible.minX + margin), visible.maxX - frame.width - margin)
    let clampedY = min(max(frame.minY, visible.minY + margin), visible.maxY - frame.height - margin)
    return NSRect(origin: NSPoint(x: clampedX, y: clampedY), size: frame.size)
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

  private func persistContent(id: UUID, content: EditorContent) {
    let colorIndex = openControllers[id]?.memo.colorTheme.colorIndex
      ?? coordinator.fetchMemo(id: id)?.colorIndex
      ?? MemoColorTheme.fallback.colorIndex
    coordinator.saveMemoContent(id: id, content: content, colorIndex: colorIndex)
  }

  private static func defaultContentSize(from appSettings: AppSettings) -> NSSize {
    NSSize(width: appSettings.defaultMemoWidth, height: appSettings.defaultMemoHeight)
  }

  private func frame(from memo: PersistedMemo) -> NSRect? {
    guard
      let originX = memo.originX,
      let originY = memo.originY,
      let width = memo.width,
      let height = memo.height
    else {
      return nil
    }

    return NSRect(x: originX, y: originY, width: width, height: height)
  }
}
