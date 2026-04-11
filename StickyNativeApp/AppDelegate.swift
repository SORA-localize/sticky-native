import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var probeWindowController: ProbeWindowController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)

    let controller = ProbeWindowController()
    probeWindowController = controller
    controller.showWindow(nil)
    controller.window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}
