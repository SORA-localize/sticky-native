import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let hotkeyManager = HotkeyManager()
  private var windowManager: WindowManager!
  private var homeWindowController: HomeWindowController!
  private var shortcutsWindowController: ShortcutsWindowController!
  private let appSettings = AppSettings.shared
  private lazy var menuBarController = MenuBarController(appSettings: appSettings)
  private var launchWindowController: LaunchWindowController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    launchWindowController = LaunchWindowController()
    launchWindowController?.show()

    guard let store = try? SQLiteStore() else {
      fatalError("Failed to open SQLite store")
    }
    let coordinator = PersistenceCoordinator(store: store)
    windowManager = WindowManager(coordinator: coordinator, appSettings: appSettings)
    homeWindowController = HomeWindowController(coordinator: coordinator)
    shortcutsWindowController = ShortcutsWindowController()

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
    launchWindowController?.finish()
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    windowManager.prepareForTermination()
    return .terminateNow
  }

  func applicationWillTerminate(_ notification: Notification) {
    hotkeyManager.unregister()
  }
}

@MainActor
private final class LaunchWindowController: NSWindowController {
  private let minimumDisplayDuration: TimeInterval = 0.75
  private let openedAt = Date()
  private var isFinishing = false

  init() {
    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: 240, height: 148),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.level = .floating
    panel.collectionBehavior = [.transient, .ignoresCycle]
    panel.hidesOnDeactivate = false
    panel.contentView = NSHostingView(rootView: LaunchProgressView())
    panel.center()

    super.init(window: panel)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    window?.alphaValue = 0
    window?.orderFrontRegardless()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.16
      window?.animator().alphaValue = 1
    }
  }

  func finish() {
    guard !isFinishing else { return }
    isFinishing = true

    let elapsed = Date().timeIntervalSince(openedAt)
    let delay = max(0, minimumDisplayDuration - elapsed)
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      self?.fadeOutAndClose()
    }
  }

  private func fadeOutAndClose() {
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0.18
      window?.animator().alphaValue = 0
    } completionHandler: { [weak self] in
      self?.close()
    }
  }
}

private struct LaunchProgressView: View {
  @State private var isPulsing = false

  var body: some View {
    VStack(spacing: 14) {
      ZStack {
        Circle()
          .fill(Color(NSColor.controlAccentColor).opacity(isPulsing ? 0.20 : 0.10))
          .frame(width: 56, height: 56)
          .scaleEffect(isPulsing ? 1.08 : 0.94)

        Image(systemName: "note.text")
          .font(.system(size: 25, weight: .medium))
          .foregroundStyle(Color(NSColor.controlAccentColor))
      }

      VStack(spacing: 6) {
        Text("StickyNative")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.primary)

        HStack(spacing: 8) {
          ProgressView()
            .controlSize(.small)
          Text(Str.launching)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
      }
    }
    .frame(width: 240, height: 148)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
    )
    .onAppear {
      withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
        isPulsing = true
      }
    }
  }
}
