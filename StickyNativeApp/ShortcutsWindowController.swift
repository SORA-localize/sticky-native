import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class ShortcutsWindowController: NSWindowController {
  private var cancellables: Set<AnyCancellable> = []

  init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 420, height: 500),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = Str.shortcutsWindowTitle
    window.center()

    super.init(window: window)

    NotificationCenter.default.publisher(for: .languageDidChange)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self else { return }
        self.window?.title = Str.shortcutsWindowTitle
        self.window?.contentView = NSHostingView(rootView: ShortcutReferenceView())
      }
      .store(in: &cancellables)

    window.contentView = NSHostingView(rootView: ShortcutReferenceView())
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }
}

struct ShortcutReferenceView: View {
  let compact: Bool

  init(compact: Bool = false) {
    self.compact = compact
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: compact ? 18 : 20) {
        ForEach(ShortcutCatalog.sections) { section in
          sectionView(section)
        }
      }
      .padding(compact ? 0 : 20)
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .frame(width: compact ? nil : 420)
  }

  private func sectionView(_ section: ShortcutSection) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(section.title)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)

      Divider()

      ForEach(section.items) { item in
        switch item.presentation {
        case .shortcut(let key, let theme):
          shortcutRow(key: key, label: item.label, theme: theme)
        case .icon(let symbolName, let key):
          iconRow(symbolName: symbolName, label: item.label, key: key)
        }
      }
    }
  }

  private func shortcutRow(key: String, label: String, theme: CommandTheme?) -> some View {
    HStack(spacing: 8) {
      if let theme {
        Circle()
          .fill(theme.color)
          .frame(width: 8, height: 8)
      }

      Text(label)
        .font(.system(size: 13))

      Spacer()

      Text(key)
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
  }

  private func iconRow(symbolName: String, label: String, key: String?) -> some View {
    HStack(spacing: 10) {
      Image(systemName: symbolName)
        .frame(width: 16)
        .foregroundStyle(.secondary)

      Text(label)
        .font(.system(size: 13))

      Spacer()

      if let key {
        Text(key)
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color(NSColor.controlBackgroundColor))
          .clipShape(RoundedRectangle(cornerRadius: 4))
      }
    }
  }
}

@MainActor
private enum ShortcutCatalog {
  static var sections: [ShortcutSection] {
    [
      ShortcutSection(
        title: Str.shortcutsSectionGlobal,
        items: [
          ShortcutItem(label: Str.shortcutsNewMemo, presentation: .shortcut("⌘ + ⌥ + Enter", nil)),
        ]
      ),
      ShortcutSection(
        title: Str.shortcutsSectionMemoWindow,
        items: [
          ShortcutItem(label: Str.shortcutsSave, presentation: .shortcut("⌘ + S", .save)),
          ShortcutItem(label: Str.shortcutsSaveAndClose, presentation: .shortcut("⌘ + Enter", .saveAndClose)),
          ShortcutItem(label: Str.shortcutsClose, presentation: .shortcut("⌘ + W", .close)),
          ShortcutItem(label: Str.shortcutsMoveToTrash, presentation: .shortcut("⌘ + ⌫", .trash)),
        ] + EditorCommand.allCases.map {
          ShortcutItem(label: $0.label, presentation: .shortcut($0.shortcutDisplay, nil))
        }
      ),
      ShortcutSection(
        title: Str.shortcutsSectionHeaderButtons,
        items: [
          ShortcutItem(label: Str.shortcutsTogglePin, presentation: .icon("pin", "⌘ + P")),
          ShortcutItem(label: Str.shortcutsMoveToTrash, presentation: .icon("trash", nil)),
          ShortcutItem(label: Str.shortcutsCloseAutosave, presentation: .icon("xmark", nil)),
        ]
      ),
    ]
  }
}

private struct ShortcutSection: Identifiable {
  let title: String
  let items: [ShortcutItem]

  var id: String { title }
}

private struct ShortcutItem: Identifiable {
  enum Presentation {
    case shortcut(String, CommandTheme?)
    case icon(String, String?)
  }

  let id = UUID()
  let label: String
  let presentation: Presentation
}
