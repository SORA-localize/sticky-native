import AppKit
import SwiftUI

@MainActor
final class MemoWindowController: NSWindowController, NSWindowDelegate {
  let memo: MemoWindow

  private let onClose: (ClosedMemoRecord) -> Void
  private let uiState: MemoWindowUIState
  private var hostingView: SeamlessHostingView<MemoWindowView>?

  init(
    memo: MemoWindow,
    origin: NSPoint?,
    initiallyPinned: Bool = false,
    onClose: @escaping (ClosedMemoRecord) -> Void
  ) {
    self.memo = memo
    self.onClose = onClose
    self.uiState = MemoWindowUIState(isPinned: initiallyPinned)

    let window = SeamlessWindow(
      contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
      styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    super.init(window: window)

    let hostingView = SeamlessHostingView(rootView: makeRootView())
    hostingView.frame = CGRect(origin: .zero, size: window.frame.size)
    hostingView.autoresizingMask = NSView.AutoresizingMask(arrayLiteral: .width, .height)
    self.hostingView = hostingView

    window.contentView = hostingView
    window.delegate = self
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = false
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.setFrameAutosaveName("MemoWindow-\(memo.id.uuidString)")

    if let origin {
      window.setFrameOrigin(origin)
    } else {
      window.center()
    }

    applyPinState()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func showAndFocusEditor() {
    requestEditorFocus()
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func pinWindow(_ pinned: Bool) {
    uiState.isPinned = pinned
    applyPinState()
  }

  func windowWillClose(_ notification: Notification) {
    onClose(
      ClosedMemoRecord(
        memoID: memo.id,
        origin: window?.frame.origin,
        isPinned: uiState.isPinned
      )
    )
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
      onClose: { [weak self] in
        self?.window?.performClose(nil)
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
