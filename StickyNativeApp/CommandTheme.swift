import SwiftUI

enum CommandTheme: Equatable {
  case save
  case saveAndClose
  case close
  case trash

  var color: Color {
    switch self {
    case .save:         return Color(red: 0.30, green: 0.64, blue: 0.96)
    case .saveAndClose: return Color(red: 0.20, green: 0.79, blue: 0.48)
    case .close:        return Color(red: 0.96, green: 0.78, blue: 0.26)
    case .trash:        return Color(red: 0.96, green: 0.38, blue: 0.38)
    }
  }

  var label: String {
    switch self {
    case .save:         return "保存"
    case .saveAndClose: return "保存して閉じる"
    case .close:        return "閉じる"
    case .trash:        return "ゴミ箱に移す"
    }
  }
}
