import AppKit
import SwiftUI

@MainActor
final class ProbeWindowController: NSWindowController, NSWindowDelegate {
  init() {
    let window = SeamlessWindow(
      contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
      styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    super.init(window: window)

    let hostingController = NSHostingController(rootView: AnyView(ProbeEditorView()))
    window.contentViewController = hostingController
    window.delegate = self
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isMovableByWindowBackground = true
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.center()
    window.setFrameAutosaveName("SeamlessProbeWindow")
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
