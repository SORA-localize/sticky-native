import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var probeWindowController: ProbeWindowController?
  private let hotkeyManager = HotkeyManager()

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)

    let controller = ProbeWindowController()
    probeWindowController = controller
    controller.showAndFocusEditor()

    hotkeyManager.onTrigger = { [weak self] in
      self?.probeWindowController?.showAndFocusEditor()
    }
    hotkeyManager.registerNewMemoShortcut()
  }

  func applicationWillTerminate(_ notification: Notification) {
    hotkeyManager.unregister()
  }
}
