import AppKit

@MainActor
final class MenuBarController: NSObject {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let menu = NSMenu()
  private let newMemoItem = NSMenuItem(title: "New Memo", action: #selector(handleNewMemo), keyEquivalent: "")
  private let reopenItem = NSMenuItem(title: "Reopen Last Closed", action: #selector(handleReopen), keyEquivalent: "")
  private let quitItem = NSMenuItem(title: "Quit StickyNative", action: #selector(handleQuit), keyEquivalent: "")

  var onNewMemo: (() -> Void)?
  var onReopenLastClosed: (() -> Void)?

  override init() {
    super.init()

    if let button = statusItem.button {
      button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "StickyNative")
      button.imagePosition = .imageOnly
    }

    newMemoItem.target = self
    reopenItem.target = self
    quitItem.target = self

    menu.items = [
      newMemoItem,
      reopenItem,
      NSMenuItem.separator(),
      quitItem,
    ]

    statusItem.menu = menu
    update(canReopen: false)
  }

  func update(canReopen: Bool) {
    reopenItem.isEnabled = canReopen
  }

  @objc private func handleNewMemo() {
    onNewMemo?()
  }

  @objc private func handleReopen() {
    onReopenLastClosed?()
  }

  @objc private func handleQuit() {
    NSApp.terminate(nil)
  }
}
