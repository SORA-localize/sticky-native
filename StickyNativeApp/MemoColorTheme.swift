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
    baseColor.opacity(0.78)
  }

  var chromeTintColor: Color {
    baseColor.opacity(0.11)
  }

  var editorTintColor: Color {
    baseColor.opacity(0.08)
  }

  var borderColor: Color {
    baseColor.opacity(0.16)
  }

  private var baseColor: Color {
    switch self {
    case .sand:
      return Color(red: 0.88, green: 0.78, blue: 0.63)
    case .mint:
      return Color(red: 0.67, green: 0.84, blue: 0.77)
    case .sky:
      return Color(red: 0.66, green: 0.79, blue: 0.91)
    case .coral:
      return Color(red: 0.89, green: 0.69, blue: 0.66)
    case .slate:
      return Color(red: 0.69, green: 0.74, blue: 0.84)
    }
  }
}
