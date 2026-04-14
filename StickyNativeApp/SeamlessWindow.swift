import AppKit

final class SeamlessWindow: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  override func becomeKey() {
    NSLog("[SeamlessWindow] becomeKey")
    NSApp.activate(ignoringOtherApps: true)
    super.becomeKey()
  }

  override func makeKey() {
    NSLog("[SeamlessWindow] makeKey")
    super.makeKey()
  }

  override func orderFront(_ sender: Any?) {
    NSLog("[SeamlessWindow] orderFront")
    super.orderFront(sender)
  }

  override func orderFrontRegardless() {
    NSLog("[SeamlessWindow] orderFrontRegardless")
    super.orderFrontRegardless()
  }

  override func makeKeyAndOrderFront(_ sender: Any?) {
    NSLog("[SeamlessWindow] makeKeyAndOrderFront")
    super.makeKeyAndOrderFront(sender)
  }
}
