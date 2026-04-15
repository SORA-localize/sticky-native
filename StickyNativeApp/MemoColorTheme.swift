import SwiftUI

enum MemoColorTheme: Int, CaseIterable {
  case sand = 0
  case mint = 1
  case sky = 2
  case coral = 3
  case slate = 4

  static let fallback: MemoColorTheme = .sand

  static func from(index: Int) -> MemoColorTheme {
    MemoColorTheme(rawValue: index) ?? fallback
  }

  var colorIndex: Int {
    rawValue
  }

  var headerDotColor: Color {
    baseColor.opacity(0.92)
  }

  var chromeTintColor: Color {
    baseColor.opacity(0.18)
  }

  var editorTintColor: Color {
    baseColor.opacity(0.12)
  }

  var borderColor: Color {
    baseColor.opacity(0.24)
  }

  private var baseColor: Color {
    switch self {
    case .sand:
      return Color(red: 0.92, green: 0.75, blue: 0.49)
    case .mint:
      return Color(red: 0.52, green: 0.84, blue: 0.72)
    case .sky:
      return Color(red: 0.49, green: 0.73, blue: 0.96)
    case .coral:
      return Color(red: 0.95, green: 0.58, blue: 0.54)
    case .slate:
      return Color(red: 0.60, green: 0.68, blue: 0.82)
    }
  }
}
