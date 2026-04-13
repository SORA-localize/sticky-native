import AppKit
import Combine
import SwiftUI

@MainActor
final class MemoWindowController: NSWindowController, NSWindowDelegate {
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
    origin: NSPoint?,
    size: NSSize? = nil,
    initiallyPinned: Bool = false,
    appSettings: AppSettings = .shared,
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
      contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
      styleMask: [.borderless, .resizable, .fullSizeContentView, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    window.becomesKeyOnlyIfNeeded = true

    super.init(window: window)

    let hostingView = SeamlessHostingView(rootView: makeRootView().environmentObject(appSettings))
    hostingView.frame = CGRect(origin: .zero, size: window.frame.size)
    hostingView.autoresizingMask = NSView.AutoresizingMask(arrayLiteral: .width, .height)
    self.hostingView = hostingView

    window.contentView = hostingView
    window.delegate = self
    window.isMovableByWindowBackground = true
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.setFrameAutosaveName("MemoWindow-\(memo.id.uuidString)")

    if let size {
      window.setContentSize(size)
    }
    if let origin {
      window.setFrameOrigin(origin)
    } else {
      window.center()
    }

    applyPinState()

    draftCancellable = memo.$draft
      .dropFirst()
      .sink { [weak self] draft in
        guard let self else { return }
        onDraftChange(memo.id, draft)
      }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func showAndFocusEditor() {
    requestEditorFocus()
    showWindow(nil)
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
    window?.orderFrontRegardless()
  }

  func pinWindow(_ pinned: Bool) {
    uiState.isPinned = pinned
    applyPinState()
    onPinChange(memo.id, pinned)
  }

  func windowWillClose(_ notification: Notification) {
    if !didExplicitFlush {
      onFlush(memo.id, memo.draft)
    }
    onClose(ClosedMemoRecord(memoID: memo.id, frame: window?.frame))
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
        didExplicitFlush = true
        onFlush(memo.id, memo.draft)
        window?.close()
      }
    )
  }

  private func applyPinState() {
    window?.level = uiState.isPinned ? .floating : .normal
  }

  private func requestEditorFocus() {
    uiState.requestEditorFocus()
  }
}
