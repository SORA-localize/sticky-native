import AppKit
import SwiftUI

@MainActor
final class ShortcutsWindowController: NSWindowController {
  init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 360, height: 380),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "Keyboard Shortcuts"
    window.center()

    super.init(window: window)

    window.contentView = NSHostingView(rootView: ShortcutsView())
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

private struct ShortcutsView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        section("グローバル") {
          row(key: "⌘ + ⌥ + Enter", label: "新しいメモを作成")
        }

        section("メモウィンドウ") {
          row(key: "⌘ + S",     label: "保存")
          row(key: "⌘ + Enter", label: "保存して閉じる")
          row(key: "⌘ + W",     label: "閉じる")
          row(key: "⌘ + ⌫",    label: "ゴミ箱に移す（確認あり）")
        }

        section("ヘッダボタン") {
          row(icon: "pin",   label: "常時前面 ON / OFF")
          row(icon: "trash", label: "ゴミ箱に移す（確認あり）")
          row(icon: "xmark", label: "閉じる（自動保存）")
        }
      }
      .padding(20)
    }
    .frame(width: 360)
  }

  private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
      Divider()
      content()
    }
  }

  private func row(key: String, label: String) -> some View {
    HStack {
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

  private func row(icon: String, label: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .frame(width: 16)
        .foregroundStyle(.secondary)
      Text(label)
        .font(.system(size: 13))
      Spacer()
    }
  }
}
