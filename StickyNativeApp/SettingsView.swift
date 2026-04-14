import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var appSettings: AppSettings
  @State private var selection: SettingsSection? = .font

  enum SettingsSection: String, CaseIterable, Identifiable {
    case font = "Font Size"
    case memo = "Memo Size"
    case hotkeys = "Hotkeys"
    var id: String { rawValue }

    var icon: String {
      switch self {
      case .font:    return "textformat.size"
      case .memo:    return "rectangle.expand.vertical"
      case .hotkeys: return "keyboard"
      }
    }
  }

  var body: some View {
    NavigationSplitView {
      List(SettingsSection.allCases, selection: $selection) { section in
        Label(section.rawValue, systemImage: section.icon)
          .tag(section)
      }
      .navigationSplitViewColumnWidth(160)
    } detail: {
      Group {
        switch selection {
        case .font:    FontSizeSettings()
        case .memo:    MemoSizeSettings()
        case .hotkeys: HotkeysSettings()
        case nil:      FontSizeSettings()
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding(24)
    }
    .environmentObject(appSettings)
  }
}

private struct FontSizeSettings: View {
  @EnvironmentObject var appSettings: AppSettings

  private let fontSizes: [(label: String, value: Double)] = [
    ("小", 13), ("中", 16), ("大", 19),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("エディタのフォントサイズ")
        .font(.headline)
      Picker("", selection: $appSettings.editorFontSize) {
        ForEach(fontSizes, id: \.value) { item in
          Text(item.label).tag(item.value)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 180)
    }
  }
}

private struct MemoSizeSettings: View {
  @EnvironmentObject var appSettings: AppSettings

  private let presets: [(label: String, width: Double, height: Double)] = [
    ("小", 360, 240),
    ("中", 440, 300),
    ("大", 560, 380),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("新規メモのデフォルトサイズ")
        .font(.headline)

      Picker("", selection: Binding(
        get: {
          presets.first {
            $0.width == appSettings.defaultMemoWidth &&
            $0.height == appSettings.defaultMemoHeight
          }?.label ?? "カスタム"
        },
        set: { label in
          if let preset = presets.first(where: { $0.label == label }) {
            appSettings.defaultMemoWidth = preset.width
            appSettings.defaultMemoHeight = preset.height
          }
        }
      )) {
        ForEach(presets, id: \.label) { preset in
          Text(preset.label).tag(preset.label)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 180)

      Text("\(Int(appSettings.defaultMemoWidth)) × \(Int(appSettings.defaultMemoHeight)) pt")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
  }
}

private struct HotkeysSettings: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("グローバルショートカット")
        .font(.headline)

      HStack {
        Text("新規メモを作成")
          .font(.system(size: 13))
        Spacer()
        Text("⌘ + ⌥ + Enter")
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color(NSColor.controlBackgroundColor))
          .clipShape(RoundedRectangle(cornerRadius: 4))
      }
      .frame(maxWidth: 280)

      Text("カスタマイズは今後対応予定です。")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
  }
}
