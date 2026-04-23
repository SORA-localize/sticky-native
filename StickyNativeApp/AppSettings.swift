import Foundation

enum AppLanguage: String {
  case english, japanese

  static func defaultLanguage() -> AppLanguage {
    guard let saved = UserDefaults.standard.string(forKey: "appLanguage") else {
      return .english
    }
    return AppLanguage(rawValue: saved) ?? .english
  }
}

enum MemoColorMode: Int, CaseIterable {
  case `default` = 0
  case colorful = 1

  static let fallback: MemoColorMode = .default

  static func from(rawValue: Int) -> MemoColorMode {
    MemoColorMode(rawValue: rawValue) ?? fallback
  }
}

@MainActor
final class AppSettings: ObservableObject {
  static let shared = AppSettings()

  private enum Keys {
    static let editorFontSize = "editorFontSize"
    static let defaultMemoWidth = "defaultMemoWidth"
    static let defaultMemoHeight = "defaultMemoHeight"
    static let nextMemoColorIndex = "nextMemoColorIndex"
    static let memoColorMode = "memoColorMode"
    static let language = "appLanguage"
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

  @Published var memoColorMode: MemoColorMode {
    didSet { UserDefaults.standard.set(memoColorMode.rawValue, forKey: Keys.memoColorMode) }
  }

  @Published var language: AppLanguage {
    didSet { UserDefaults.standard.set(language.rawValue, forKey: Keys.language) }
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

    let storedMemoColorMode = UserDefaults.standard.object(forKey: Keys.memoColorMode) as? Int
    self.memoColorMode = MemoColorMode.from(rawValue: storedMemoColorMode ?? MemoColorMode.fallback.rawValue)

    self.language = AppLanguage.defaultLanguage()
  }

  func makeNewMemoColorTheme() -> MemoColorTheme {
    switch memoColorMode {
    case .default:
      return .plain
    case .colorful:
      let theme = MemoColorTheme.from(index: nextMemoColorIndex)
      nextMemoColorIndex = (theme.colorIndex + 1) % MemoColorTheme.colorfulCases.count
      return theme
    }
  }
}
