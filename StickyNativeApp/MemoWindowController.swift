import AppKit
import Combine
import SwiftUI

@MainActor
final class MemoWindowController: NSWindowController, NSWindowDelegate {
  static let defaultContentSize = NSSize(width: 440, height: 300)
  static let minimumContentSize = NSSize(width: 320, height: 220)

  let memo: MemoWindow

  private let onClose: (ClosedMemoRecord) -> Void
  private let onDraftChange: (UUID, String) -> Void
  private let onFlush: (UUID, String) -> Void
  private let onPinChange: (UUID, Bool) -> Void
  private let onTrash: (UUID) -> Void
  private let uiState: MemoWindowUIState
  private let appSettings: AppSettings
  private var hostingView: NSView?
  private var draftCancellable: AnyCancellable?
  private var didExplicitFlush = false

  init(
    memo: MemoWindow,
    origin: NSPoint? = nil,
    contentSize: NSSize? = nil,
    savedFrame: NSRect? = nil,
    initiallyPinned: Bool = false,
    appSettings: AppSettings,
    onDraftChange: @escaping (UUID, String) -> Void,
    onFlush: @escaping (UUID, String) -> Void,
    onPinChange: @escaping (UUID, Bool) -> Void,
    onTrash: @escaping (UUID) -> Void,
    onClose: @escaping (ClosedMemoRecord) -> Void
  ) {
    self.memo = memo
    self.onClose = onClose
    self.onDraftChange = onDraftChange
    self.onFlush = onFlush
    self.onPinChange = onPinChange
    self.onTrash = onTrash
    self.uiState = MemoWindowUIState(isPinned: initiallyPinned)
    self.appSettings = appSettings

    let window = SeamlessWindow(
      contentRect: NSRect(origin: .zero, size: Self.defaultContentSize),
      styleMask: [.titled, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.hidesOnDeactivate = false
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true

    super.init(window: window)

    let hostingView = SeamlessHostingView(rootView: makeRootView().environmentObject(appSettings))
    hostingView.frame = CGRect(origin: .zero, size: window.frame.size)
    hostingView.autoresizingMask = NSView.AutoresizingMask(arrayLiteral: .width, .height)
    self.hostingView = hostingView

    window.contentView = hostingView
    window.delegate = self
    window.isMovableByWindowBackground = false
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.contentMinSize = Self.minimumContentSize
    window.setFrameAutosaveName("MemoWindow-\(memo.id.uuidString)")
    hideStandardWindowButtons(in: window)

    if let savedFrame {
      window.setFrame(savedFrame, display: false)
    } else if let contentSize {
      window.setContentSize(contentSize)
    }

    if savedFrame == nil, let origin {
      window.setFrameOrigin(origin)
    } else if savedFrame == nil {
      window.center()
    }

    applyPinState()

    draftCancellable = memo.$draft
      .dropFirst()
      .sink { draft in
        onDraftChange(memo.id, draft)
      }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func showAndFocusEditor() {
    requestEditorFocus()
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
  }

  func pinWindow(_ pinned: Bool) {
    uiState.isPinned = pinned
    applyPinState()
    onPinChange(memo.id, pinned)
  }

  func windowDidBecomeKey(_ notification: Notification) {
    NSLog("[MemoWindowController] windowDidBecomeKey")
  }

  func windowDidBecomeMain(_ notification: Notification) {
    NSLog("[MemoWindowController] windowDidBecomeMain")
  }

  static func isDraftEmpty(_ draft: String) -> Bool {
    draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  func windowWillClose(_ notification: Notification) {
    if Self.isDraftEmpty(memo.draft) {
      onClose(ClosedMemoRecord(memoID: memo.id, frame: nil, isAutoDelete: true))
    } else {
      if !didExplicitFlush {
        onFlush(memo.id, memo.draft)
      }
      onClose(ClosedMemoRecord(memoID: memo.id, frame: window?.frame))
    }
  }

  var currentFrame: NSRect? {
    window?.frame
  }

  var pinnedState: Bool {
    uiState.isPinned
  }

  private func makeRootView() -> MemoWindowView {
    MemoWindowView(
      memo: memo,
      uiState: uiState,
      onPinToggle: { [weak self] in
        guard let self else { return }
        pinWindow(!uiState.isPinned)
      },
      onTrash: { [weak self] in
        guard let self else { return }
        onTrash(memo.id)
      },
      onClose: { [weak self] in
        self?.window?.close()
      },
      onSave: { [weak self] in
        guard let self else { return }
        onFlush(memo.id, memo.draft)
      },
      onSaveAndClose: { [weak self] in
        guard let self else { return }
        if !Self.isDraftEmpty(memo.draft) {
          didExplicitFlush = true
          onFlush(memo.id, memo.draft)
        }
        window?.close()
      }
    )
  }

  private func applyPinState() {
    if uiState.isPinned {
      window?.level = .floating
      window?.collectionBehavior = [.managed, .fullScreenAuxiliary]
    } else {
      window?.level = .normal
      window?.collectionBehavior = .managed
    }
  }

  private func requestEditorFocus() {
    uiState.requestEditorFocus()
  }

  private func hideStandardWindowButtons(in window: NSWindow) {
    window.standardWindowButton(.closeButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true
  }
}
