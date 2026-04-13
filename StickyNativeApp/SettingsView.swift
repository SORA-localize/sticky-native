import SwiftUI

struct SettingsView: View {
  @EnvironmentObject var appSettings: AppSettings

  private let fontSizes: [(label: String, value: Double)] = [
    ("小", 13),
    ("中", 16),
    ("大", 19),
  ]

  var body: some View {
    Form {
      Picker("エディタのフォントサイズ", selection: $appSettings.editorFontSize) {
        ForEach(fontSizes, id: \.value) { item in
          Text(item.label).tag(item.value)
        }
      }
      .pickerStyle(.segmented)
    }
    .padding(24)
    .frame(width: 320, height: 100)
  }
}
