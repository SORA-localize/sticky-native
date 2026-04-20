import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let menu = NSMenu()

  private let newMemoItem    = NSMenuItem(title: "新規メモ", action: #selector(handleNewMemo),  keyEquivalent: "")
  private let allMemosItem   = NSMenuItem(title: "すべてのメモ", action: #selector(handleOpenHome), keyEquivalent: "")
  private let reopenItem     = NSMenuItem(title: "最後に閉じたメモを開く", action: #selector(handleReopen),   keyEquivalent: "")
  private let shortcutsItem  = NSMenuItem(title: "キーボードショートカット...", action: #selector(handleOpenShortcuts), keyEquivalent: "")
  private let quitItem       = NSMenuItem(title: "StickyNativeを終了", action: #selector(handleQuit),     keyEquivalent: "")

  // Font Size submenu
  private let fontSmallItem  = NSMenuItem(title: "小", action: #selector(setFontSmall),  keyEquivalent: "")
  private let fontMediumItem = NSMenuItem(title: "中", action: #selector(setFontMedium), keyEquivalent: "")
  private let fontLargeItem  = NSMenuItem(title: "大", action: #selector(setFontLarge),  keyEquivalent: "")

  // Memo Size submenu
  private let memoSmallItem  = NSMenuItem(title: "小", action: #selector(setMemoSmall),  keyEquivalent: "")
  private let memoMediumItem = NSMenuItem(title: "中", action: #selector(setMemoMedium), keyEquivalent: "")
  private let memoLargeItem  = NSMenuItem(title: "大", action: #selector(setMemoLarge),  keyEquivalent: "")

  // Memo Color submenu
  private let memoColorDefaultItem  = NSMenuItem(title: "デフォルト", action: #selector(setMemoColorDefault), keyEquivalent: "")
  private let memoColorColorfulItem = NSMenuItem(title: "カラフル", action: #selector(setMemoColorColorful), keyEquivalent: "")

  private let appSettings: AppSettings

  var onNewMemo: (() -> Void)?
  var onOpenHome: (() -> Void)?
  var onReopenLastClosed: (() -> Void)?
  var onOpenShortcuts: (() -> Void)?

  init(appSettings: AppSettings) {
    self.appSettings = appSettings
    super.init()

    if let button = statusItem.button {
      button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "StickyNative")
      button.imagePosition = .imageOnly
    }

    let allItems = [
      newMemoItem, allMemosItem, reopenItem, shortcutsItem, quitItem,
      fontSmallItem, fontMediumItem, fontLargeItem,
      memoSmallItem, memoMediumItem, memoLargeItem,
      memoColorDefaultItem, memoColorColorfulItem,
    ]
    allItems.forEach { $0.target = self }

    // Font Size submenu
    let fontSizeMenu = NSMenu()
    fontSizeMenu.items = [fontSmallItem, fontMediumItem, fontLargeItem]
    let fontSizeParent = NSMenuItem(title: "文字サイズ", action: nil, keyEquivalent: "")
    fontSizeParent.submenu = fontSizeMenu

    // Memo Size submenu
    let memoSizeMenu = NSMenu()
    memoSizeMenu.items = [memoSmallItem, memoMediumItem, memoLargeItem]
    let memoSizeParent = NSMenuItem(title: "メモサイズ", action: nil, keyEquivalent: "")
    memoSizeParent.submenu = memoSizeMenu

    let memoColorMenu = NSMenu()
    memoColorMenu.items = [memoColorDefaultItem, memoColorColorfulItem]
    let memoColorParent = NSMenuItem(title: "メモカラー", action: nil, keyEquivalent: "")
    memoColorParent.submenu = memoColorMenu

    // Hotkeys submenu（表示のみ）
    let hotkeyItem = NSMenuItem(title: "新規メモ作成    ⌘ + ⌥ + Enter", action: nil, keyEquivalent: "")
    hotkeyItem.isEnabled = false
    let hotkeysMenu = NSMenu()
    hotkeysMenu.items = [hotkeyItem]
    let hotkeysParent = NSMenuItem(title: "ショートカット", action: nil, keyEquivalent: "")
    hotkeysParent.submenu = hotkeysMenu

    menu.autoenablesItems = false
    menu.delegate = self
    menu.items = [
      sectionHeader("メモ"),
      newMemoItem,
      allMemosItem,
      reopenItem,
      NSMenuItem.separator(),
      sectionHeader("設定"),
      fontSizeParent,
      memoSizeParent,
      memoColorParent,
      hotkeysParent,
      NSMenuItem.separator(),
      shortcutsItem,
      NSMenuItem.separator(),
      quitItem,
    ]

    statusItem.menu = menu
    update(canReopen: false)
    updateCheckmarks()
  }

  func update(canReopen: Bool) {
    reopenItem.isEnabled = canReopen
  }

  // MARK: - NSMenuDelegate

  func menuWillOpen(_ menu: NSMenu) {
    updateCheckmarks()
  }

  // MARK: - Private

  private func updateCheckmarks() {
    let fontSize = appSettings.editorFontSize
    fontSmallItem.state  = fontSize == 13 ? .on : .off
    fontMediumItem.state = fontSize == 16 ? .on : .off
    fontLargeItem.state  = fontSize == 19 ? .on : .off

    let w = appSettings.defaultMemoWidth
    let h = appSettings.defaultMemoHeight
    memoSmallItem.state  = (w == 360 && h == 240) ? .on : .off
    memoMediumItem.state = (w == 440 && h == 300) ? .on : .off
    memoLargeItem.state  = (w == 560 && h == 380) ? .on : .off

    memoColorDefaultItem.state = appSettings.memoColorMode == .default ? .on : .off
    memoColorColorfulItem.state = appSettings.memoColorMode == .colorful ? .on : .off
  }

  private func sectionHeader(_ title: String) -> NSMenuItem {
    let item = NSMenuItem()
    item.isEnabled = false
    item.attributedTitle = NSAttributedString(
      string: title,
      attributes: [
        .font: NSFont.systemFont(ofSize: 10, weight: .medium),
        .foregroundColor: NSColor.secondaryLabelColor,
      ]
    )
    return item
  }

  // MARK: - Actions

  @objc private func setFontSmall()  { appSettings.editorFontSize = 13; updateCheckmarks() }
  @objc private func setFontMedium() { appSettings.editorFontSize = 16; updateCheckmarks() }
  @objc private func setFontLarge()  { appSettings.editorFontSize = 19; updateCheckmarks() }

  @objc private func setMemoSmall()  { appSettings.defaultMemoWidth = 360; appSettings.defaultMemoHeight = 240; updateCheckmarks() }
  @objc private func setMemoMedium() { appSettings.defaultMemoWidth = 440; appSettings.defaultMemoHeight = 300; updateCheckmarks() }
  @objc private func setMemoLarge()  { appSettings.defaultMemoWidth = 560; appSettings.defaultMemoHeight = 380; updateCheckmarks() }

  @objc private func setMemoColorDefault()  { appSettings.memoColorMode = .default; updateCheckmarks() }
  @objc private func setMemoColorColorful() { appSettings.memoColorMode = .colorful; updateCheckmarks() }

  @objc private func handleNewMemo()      { onNewMemo?() }
  @objc private func handleOpenHome()     { onOpenHome?() }
  @objc private func handleReopen()       { onReopenLastClosed?() }
  @objc private func handleOpenShortcuts() { onOpenShortcuts?() }
  @objc private func handleQuit()         { NSApp.terminate(nil) }
}
