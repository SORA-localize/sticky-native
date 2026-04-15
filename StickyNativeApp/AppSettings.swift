import Foundation

@MainActor
final class AppSettings: ObservableObject {
  static let shared = AppSettings()

  private enum Keys {
    static let editorFontSize = "editorFontSize"
    static let defaultMemoWidth = "defaultMemoWidth"
    static let defaultMemoHeight = "defaultMemoHeight"
    static let nextMemoColorIndex = "nextMemoColorIndex"
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

  @Published var nextMemoColorIndex: Int {
    didSet { UserDefaults.standard.set(nextMemoColorIndex, forKey: Keys.nextMemoColorIndex) }
  }

  private init() {
    let storedFontSize = UserDefaults.standard.double(forKey: Keys.editorFontSize)
    self.editorFontSize = storedFontSize > 0 ? storedFontSize : 16

    let storedWidth = UserDefaults.standard.double(forKey: Keys.defaultMemoWidth)
    self.defaultMemoWidth = storedWidth > 0 ? storedWidth : 440

    let storedHeight = UserDefaults.standard.double(forKey: Keys.defaultMemoHeight)
    self.defaultMemoHeight = storedHeight > 0 ? storedHeight : 300

    let storedColorIndex = UserDefaults.standard.object(forKey: Keys.nextMemoColorIndex) as? Int
    self.nextMemoColorIndex = MemoColorTheme.from(index: storedColorIndex ?? 0).colorIndex
  }

  func reserveNextMemoColorTheme() -> MemoColorTheme {
    let theme = MemoColorTheme.from(index: nextMemoColorIndex)
    nextMemoColorIndex = (theme.colorIndex + 1) % MemoColorTheme.allCases.count
    return theme
  }
}
