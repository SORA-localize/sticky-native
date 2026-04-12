import AppKit
import SwiftUI

@MainActor
final class MemoWindowController: NSWindowController, NSWindowDelegate {
  let memo: MemoWindow

  private let onClose: (UUID) -> Void
  private var isPinned = false
  private var focusToken = UUID()
  private var hostingView: SeamlessHostingView<MemoWindowView>?

  init(memo: MemoWindow, origin: NSPoint?, onClose: @escaping (UUID) -> Void) {
    self.memo = memo
    self.onClose = onClose

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
    isPinned = pinned
    applyPinState()
    refreshRootView()
  }

  func windowWillClose(_ notification: Notification) {
    onClose(memo.id)
  }

  func windowDidBecomeKey(_ notification: Notification) {
    requestEditorFocus()
  }

  var currentFrame: NSRect? {
    window?.frame
  }

  private func makeRootView() -> MemoWindowView {
    MemoWindowView(
      memo: memo,
      focusToken: focusToken,
      isPinned: isPinned,
      onPinToggle: { [weak self] in
        guard let self else { return }
        pinWindow(!isPinned)
      },
      onClose: { [weak self] in
        self?.window?.performClose(nil)
      }
    )
  }

  private func refreshRootView() {
    hostingView?.rootView = makeRootView()
  }

  private func applyPinState() {
    window?.level = isPinned ? .floating : .normal
  }

  private func requestEditorFocus() {
    focusToken = UUID()
    refreshRootView()
  }
}
