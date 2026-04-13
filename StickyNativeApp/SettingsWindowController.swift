import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
  init(appSettings: AppSettings) {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 320, height: 100),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "Settings"
    window.center()

    super.init(window: window)

    window.contentView = NSHostingView(
      rootView: SettingsView().environmentObject(appSettings)
    )
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }
}
