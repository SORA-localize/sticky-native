import AppKit
import Combine
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
  private var cancellables: Set<AnyCancellable> = []

  init(appSettings: AppSettings) {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 500, height: 280),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = Str.settingsWindowTitle
    window.center()

    super.init(window: window)

    NotificationCenter.default.publisher(for: .languageDidChange)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in self?.window?.title = Str.settingsWindowTitle }
      .store(in: &cancellables)

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
