import AppKit

@MainActor
final class MenuBarController: NSObject {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let menu = NSMenu()
  private let newMemoItem = NSMenuItem(title: "New Memo", action: #selector(handleNewMemo), keyEquivalent: "")
  private let allMemosItem = NSMenuItem(title: "All Memos", action: #selector(handleOpenHome), keyEquivalent: "")
  private let reopenItem = NSMenuItem(title: "Reopen Last Closed", action: #selector(handleReopen), keyEquivalent: "")
  private let settingsItem = NSMenuItem(title: "Settings...", action: #selector(handleOpenSettings), keyEquivalent: ",")
  private let quitItem = NSMenuItem(title: "Quit StickyNative", action: #selector(handleQuit), keyEquivalent: "")

  var onNewMemo: (() -> Void)?
  var onOpenHome: (() -> Void)?
  var onReopenLastClosed: (() -> Void)?
  var onOpenSettings: (() -> Void)?

  override init() {
    super.init()

    if let button = statusItem.button {
      button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "StickyNative")
      button.imagePosition = .imageOnly
    }

    newMemoItem.target = self
    allMemosItem.target = self
    reopenItem.target = self
    settingsItem.target = self
    quitItem.target = self

    menu.autoenablesItems = false
    menu.items = [
      newMemoItem,
      allMemosItem,
      reopenItem,
      NSMenuItem.separator(),
      settingsItem,
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

  @objc private func handleOpenHome() {
    onOpenHome?()
  }

  @objc private func handleReopen() {
    onReopenLastClosed?()
  }

  @objc private func handleOpenSettings() {
    onOpenSettings?()
  }

  @objc private func handleQuit() {
    NSApp.terminate(nil)
  }
}
