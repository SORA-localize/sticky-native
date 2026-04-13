import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let hotkeyManager = HotkeyManager()
  private var windowManager: WindowManager!
  private var homeWindowController: HomeWindowController!
  private var settingsWindowController: SettingsWindowController!
  private let menuBarController = MenuBarController()
  private let appSettings = AppSettings.shared

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)

    guard let store = try? SQLiteStore() else {
      fatalError("Failed to open SQLite store")
    }
    let coordinator = PersistenceCoordinator(store: store)
    windowManager = WindowManager(coordinator: coordinator, appSettings: appSettings)
    homeWindowController = HomeWindowController(coordinator: coordinator)
    settingsWindowController = SettingsWindowController(appSettings: appSettings)

    homeWindowController.onOpenMemo = { [weak self] id in
      self?.windowManager.openMemo(id: id)
    }
    homeWindowController.onTrashMemo = { [weak self] id in
      self?.windowManager.trashMemo(id: id)
    }
    homeWindowController.onRestoreMemo = { [weak self] id in
      self?.windowManager.restoreMemo(id: id)
    }
    homeWindowController.onEmptyTrash = { [weak self] in
      self?.windowManager.emptyTrash()
    }

    menuBarController.onNewMemo = { [weak self] in
      self?.windowManager.createNewMemoWindow()
    }
    menuBarController.onOpenHome = { [weak self] in
      self?.homeWindowController.show()
    }
    menuBarController.onReopenLastClosed = { [weak self] in
      self?.windowManager.reopenLastClosedMemo()
    }
    menuBarController.onOpenSettings = { [weak self] in
      self?.settingsWindowController.show()
    }

    windowManager.onClosedStackChanged = { [weak self] in
      guard let self else { return }
      menuBarController.update(canReopen: windowManager.canReopenClosedMemo)
      homeWindowController.viewModel.reload()
    }
    menuBarController.update(canReopen: windowManager.canReopenClosedMemo)

    hotkeyManager.onTrigger = { [weak self] in
      self?.windowManager.createNewMemoWindow()
    }
    hotkeyManager.registerNewMemoShortcut()

    windowManager.restorePersistedOpenMemos()
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    windowManager.prepareForTermination()
    return .terminateNow
  }

  func applicationWillTerminate(_ notification: Notification) {
    hotkeyManager.unregister()
  }
}
