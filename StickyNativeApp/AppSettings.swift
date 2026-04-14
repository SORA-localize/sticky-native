import Foundation

@MainActor
final class AppSettings: ObservableObject {
  static let shared = AppSettings()

  private enum Keys {
    static let editorFontSize = "editorFontSize"
    static let defaultMemoWidth = "defaultMemoWidth"
    static let defaultMemoHeight = "defaultMemoHeight"
  }

  @Published var editorFontSize: Double {
    didSet { UserDefaults.standard.set(editorFontSize, forKey: Keys.editorFontSize) }
  }

  @Published var defaultMemoWidth: Double {
    didSet { UserDefaults.standard.set(defaultMemoWidth, forKey: Keys.defaultMemoWidth) }
  }

  @Published var defaultMemoHeight: Double {
    didSet { UserDefaults.standard.set(defaultMemoHeight, forKey: Keys.defaultMemoHeight) }
  }

  private init() {
    let storedFontSize = UserDefaults.standard.double(forKey: Keys.editorFontSize)
    self.editorFontSize = storedFontSize > 0 ? storedFontSize : 16

    let storedWidth = UserDefaults.standard.double(forKey: Keys.defaultMemoWidth)
    self.defaultMemoWidth = storedWidth > 0 ? storedWidth : 440

    let storedHeight = UserDefaults.standard.double(forKey: Keys.defaultMemoHeight)
    self.defaultMemoHeight = storedHeight > 0 ? storedHeight : 300
  }
}
