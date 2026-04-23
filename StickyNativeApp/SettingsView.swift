import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var appSettings: AppSettings
  @State private var selection: SettingsSection? = .font

  enum SettingsSection: String, CaseIterable, Identifiable {
    case font = "Font Size"
    case memo = "Memo Size"
    case memoColor = "Memo Color"
    case hotkeys = "Hotkeys"
    var id: String { rawValue }

    var icon: String {
      switch self {
      case .font:      return "textformat.size"
      case .memo:      return "rectangle.expand.vertical"
      case .memoColor: return "paintpalette"
      case .hotkeys:   return "keyboard"
      }
    }

    @MainActor var displayName: String {
      switch self {
      case .font:      return Str.labelFontSize
      case .memo:      return Str.labelMemoSize
      case .memoColor: return Str.labelMemoColor
      case .hotkeys:   return Str.labelHotkeys
      }
    }
  }

  var body: some View {
    NavigationSplitView {
      List(SettingsSection.allCases, selection: $selection) { section in
        Label(section.displayName, systemImage: section.icon)
          .tag(section)
      }
      .navigationSplitViewColumnWidth(160)
    } detail: {
      Group {
        switch selection {
        case .font:    FontSizeSettings()
        case .memo:    MemoSizeSettings()
        case .memoColor: MemoColorSettings()
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

  private var fontSizes: [(label: String, value: Double)] {
    [(Str.sizeSmall, 13), (Str.sizeMedium, 16), (Str.sizeLarge, 19)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(Str.settingsFontSizeHeader)
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

  private var presets: [(label: String, width: Double, height: Double)] {
    [(Str.sizeSmall, 360, 240), (Str.sizeMedium, 440, 300), (Str.sizeLarge, 560, 380)]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(Str.settingsMemoSizeHeader)
        .font(.headline)

      Picker("", selection: Binding(
        get: {
          presets.first {
            $0.width == appSettings.defaultMemoWidth &&
            $0.height == appSettings.defaultMemoHeight
          }?.label ?? Str.settingsCustom
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

private struct MemoColorSettings: View {
  @EnvironmentObject var appSettings: AppSettings

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(Str.settingsMemoColorHeader)
        .font(.headline)

      Picker("", selection: $appSettings.memoColorMode) {
        Text(Str.colorDefault).tag(MemoColorMode.default)
        Text(Str.colorColorful).tag(MemoColorMode.colorful)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(width: 220)

      Text(description)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
  }

  private var description: String {
    switch appSettings.memoColorMode {
    case .default:  return Str.settingsColorDefaultDesc
    case .colorful: return Str.settingsColorColorfulDesc
    }
  }
}

private struct HotkeysSettings: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(Str.settingsHotkeysHeader)
        .font(.headline)

      HStack {
        Text(Str.settingsCreateMemo)
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

      Text(Str.settingsHotkeysNote)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
  }
}
