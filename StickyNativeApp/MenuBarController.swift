import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private let menu = NSMenu()

  private let newMemoItem    = NSMenuItem(title: "", action: #selector(handleNewMemo),  keyEquivalent: "")
  private let allMemosItem   = NSMenuItem(title: "", action: #selector(handleOpenHome), keyEquivalent: "")
  private let reopenItem     = NSMenuItem(title: "", action: #selector(handleReopen),   keyEquivalent: "")
  private let shortcutsItem  = NSMenuItem(title: "", action: #selector(handleOpenShortcuts), keyEquivalent: "")
  private let quitItem       = NSMenuItem(title: "", action: #selector(handleQuit),     keyEquivalent: "")

  // Font Size submenu
  private let fontSmallItem  = NSMenuItem(title: "", action: #selector(setFontSmall),  keyEquivalent: "")
  private let fontMediumItem = NSMenuItem(title: "", action: #selector(setFontMedium), keyEquivalent: "")
  private let fontLargeItem  = NSMenuItem(title: "", action: #selector(setFontLarge),  keyEquivalent: "")

  // Memo Size submenu
  private let memoSmallItem  = NSMenuItem(title: "", action: #selector(setMemoSmall),  keyEquivalent: "")
  private let memoMediumItem = NSMenuItem(title: "", action: #selector(setMemoMedium), keyEquivalent: "")
  private let memoLargeItem  = NSMenuItem(title: "", action: #selector(setMemoLarge),  keyEquivalent: "")

  // Memo Color submenu
  private let memoColorDefaultItem  = NSMenuItem(title: "", action: #selector(setMemoColorDefault), keyEquivalent: "")
  private let memoColorColorfulItem = NSMenuItem(title: "", action: #selector(setMemoColorColorful), keyEquivalent: "")

  // Language submenu
  private let languageEnglishItem  = NSMenuItem(title: "English",  action: #selector(setLanguageEnglish), keyEquivalent: "")
  private let languageJapaneseItem = NSMenuItem(title: "日本語", action: #selector(setLanguageJapanese), keyEquivalent: "")

  // Submenu parent items (need title updates)
  private let fontSizeParent  = NSMenuItem(title: "", action: nil, keyEquivalent: "")
  private let memoSizeParent  = NSMenuItem(title: "", action: nil, keyEquivalent: "")
  private let memoColorParent = NSMenuItem(title: "", action: nil, keyEquivalent: "")
  private let languageParent  = NSMenuItem(title: "", action: nil, keyEquivalent: "")
  private let memoSectionHeader  = NSMenuItem()
  private let settingsSectionHeader = NSMenuItem()
  private let helpSectionHeader = NSMenuItem()

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
      languageEnglishItem, languageJapaneseItem,
    ]
    allItems.forEach { $0.target = self }

    // Font Size submenu
    let fontSizeMenu = NSMenu()
    fontSizeMenu.items = [fontSmallItem, fontMediumItem, fontLargeItem]
    fontSizeParent.submenu = fontSizeMenu

    // Memo Size submenu
    let memoSizeMenu = NSMenu()
    memoSizeMenu.items = [memoSmallItem, memoMediumItem, memoLargeItem]
    memoSizeParent.submenu = memoSizeMenu

    // Memo Color submenu
    let memoColorMenu = NSMenu()
    memoColorMenu.items = [memoColorDefaultItem, memoColorColorfulItem]
    memoColorParent.submenu = memoColorMenu

    // Language submenu
    let languageMenu = NSMenu()
    languageMenu.items = [languageEnglishItem, languageJapaneseItem]
    languageParent.submenu = languageMenu

    // Section headers
    for header in [memoSectionHeader, settingsSectionHeader, helpSectionHeader] {
      header.isEnabled = false
    }

    menu.autoenablesItems = false
    menu.delegate = self
    menu.items = [
      memoSectionHeader,
      newMemoItem,
      allMemosItem,
      reopenItem,
      NSMenuItem.separator(),
      settingsSectionHeader,
      fontSizeParent,
      memoSizeParent,
      memoColorParent,
      languageParent,
      NSMenuItem.separator(),
      helpSectionHeader,
      shortcutsItem,
      NSMenuItem.separator(),
      quitItem,
    ]

    statusItem.menu = menu
    updateMenuTitles()
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

  private func updateMenuTitles() {
    memoSectionHeader.attributedTitle = sectionHeaderString(Str.menuSectionMemo)
    settingsSectionHeader.attributedTitle = sectionHeaderString(Str.menuSectionSettings)
    helpSectionHeader.attributedTitle = sectionHeaderString(Str.menuSectionHelp)

    newMemoItem.title    = Str.menuNewMemo
    allMemosItem.title   = Str.allMemos
    reopenItem.title     = Str.menuReopenLast
    shortcutsItem.title  = Str.menuShortcuts
    quitItem.title       = Str.menuQuit

    fontSmallItem.title  = Str.sizeSmall
    fontMediumItem.title = Str.sizeMedium
    fontLargeItem.title  = Str.sizeLarge

    memoSmallItem.title  = Str.sizeSmall
    memoMediumItem.title = Str.sizeMedium
    memoLargeItem.title  = Str.sizeLarge

    memoColorDefaultItem.title  = Str.colorDefault
    memoColorColorfulItem.title = Str.colorColorful

    fontSizeParent.title  = Str.labelFontSize
    memoSizeParent.title  = Str.labelMemoSize
    memoColorParent.title = Str.labelMemoColor
    languageParent.title  = Str.menuLanguage
  }

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

    memoColorDefaultItem.state  = appSettings.memoColorMode == .default  ? .on : .off
    memoColorColorfulItem.state = appSettings.memoColorMode == .colorful ? .on : .off

    languageEnglishItem.state  = appSettings.language == .english  ? .on : .off
    languageJapaneseItem.state = appSettings.language == .japanese ? .on : .off
  }

  private func sectionHeaderString(_ title: String) -> NSAttributedString {
    NSAttributedString(
      string: title,
      attributes: [
        .font: NSFont.systemFont(ofSize: 10, weight: .medium),
        .foregroundColor: NSColor.secondaryLabelColor,
      ]
    )
  }

  // MARK: - Actions

  @objc private func setFontSmall()  { appSettings.editorFontSize = 13; updateCheckmarks() }
  @objc private func setFontMedium() { appSettings.editorFontSize = 16; updateCheckmarks() }
  @objc private func setFontLarge()  { appSettings.editorFontSize = 19; updateCheckmarks() }

  @objc private func setMemoSmall()  { appSettings.defaultMemoWidth = 360; appSettings.defaultMemoHeight = 240; updateCheckmarks() }
  @objc private func setMemoMedium() { appSettings.defaultMemoWidth = 440; appSettings.defaultMemoHeight = 300; updateCheckmarks() }
  @objc private func setMemoLarge()  { appSettings.defaultMemoWidth = 560; appSettings.defaultMemoHeight = 380; updateCheckmarks() }

  @objc private func setMemoColorDefault()  { appSettings.memoColorMode = .default;  updateCheckmarks() }
  @objc private func setMemoColorColorful() { appSettings.memoColorMode = .colorful; updateCheckmarks() }

  @objc private func setLanguageEnglish() {
    appSettings.language = .english
    updateMenuTitles()
    updateCheckmarks()
    NotificationCenter.default.post(name: .languageDidChange, object: nil)
  }

  @objc private func setLanguageJapanese() {
    appSettings.language = .japanese
    updateMenuTitles()
    updateCheckmarks()
    NotificationCenter.default.post(name: .languageDidChange, object: nil)
  }

  @objc private func handleNewMemo()  { onNewMemo?() }
  @objc private func handleOpenHome() { onOpenHome?() }
  @objc private func handleReopen()   { onReopenLastClosed?() }
  @objc private func handleOpenShortcuts() { onOpenShortcuts?() }
  @objc private func handleQuit()     { NSApp.terminate(nil) }
}

extension Notification.Name {
  static let languageDidChange = Notification.Name("languageDidChange")
}
