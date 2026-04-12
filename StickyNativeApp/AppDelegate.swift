import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let hotkeyManager = HotkeyManager()
  private let windowManager = WindowManager()
  private let menuBarController = MenuBarController()

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)

    menuBarController.onNewMemo = { [weak self] in
      self?.windowManager.createNewMemoWindow()
    }
    menuBarController.onReopenLastClosed = { [weak self] in
      self?.windowManager.reopenLastClosedMemo()
    }

    windowManager.onClosedStackChanged = { [weak self] in
      guard let self else { return }
      menuBarController.update(canReopen: windowManager.canReopenClosedMemo)
    }
    menuBarController.update(canReopen: windowManager.canReopenClosedMemo)

    hotkeyManager.onTrigger = { [weak self] in
      self?.windowManager.createNewMemoWindow()
    }
    hotkeyManager.registerNewMemoShortcut()
  }

  func applicationWillTerminate(_ notification: Notification) {
    hotkeyManager.unregister()
  }
}
