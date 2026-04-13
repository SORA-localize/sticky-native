import Foundation

@MainActor
final class AppSettings: ObservableObject {
  static let shared = AppSettings()

  private enum Keys {
    static let editorFontSize = "editorFontSize"
  }

  @Published var editorFontSize: Double {
    didSet { UserDefaults.standard.set(editorFontSize, forKey: Keys.editorFontSize) }
  }

  private init() {
    let stored = UserDefaults.standard.double(forKey: Keys.editorFontSize)
    self.editorFontSize = stored > 0 ? stored : 16
  }
}
