import AppKit

enum EditorCommand: String, CaseIterable {
  case toggleCheckbox
  case insertDate
  case insertDateTime

  static let contextMenuCommands: [EditorCommand] = [
    .toggleCheckbox,
    .insertDate,
    .insertDateTime,
  ]

  var label: String {
    switch self {
    case .toggleCheckbox:
      return isJapanese ? "チェックボックス切り替え" : "Toggle Checkbox"
    case .insertDate:
      return isJapanese ? "日付を挿入" : "Insert Date"
    case .insertDateTime:
      return isJapanese ? "日時を挿入" : "Insert Date & Time"
    }
  }

  var menuTitle: String {
    label
  }

  var shortcutDisplay: String {
    switch self {
    case .toggleCheckbox:
      return "⌘ + L"
    case .insertDate:
      return "⌘ + D"
    case .insertDateTime:
      return "⌘ + ⇧ + D"
    }
  }

  var keyEquivalent: String {
    switch self {
    case .toggleCheckbox:
      return "l"
    case .insertDate, .insertDateTime:
      return "d"
    }
  }

  var modifierFlags: NSEvent.ModifierFlags {
    switch self {
    case .toggleCheckbox:
      return .command
    case .insertDate:
      return .command
    case .insertDateTime:
      return [.command, .shift]
    }
  }

  func matches(_ event: NSEvent) -> Bool {
    guard event.charactersIgnoringModifiers?.lowercased() == keyEquivalent else {
      return false
    }
    let relevantFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
    return relevantFlags == modifierFlags
  }

  func makeTextEdit(in text: String, selectedRange: NSRange, now: Date = Date()) -> EditorTextEdit? {
    switch self {
    case .toggleCheckbox:
      return EditorTextOperations.toggleCheckbox(in: text, selectedRange: selectedRange)
    case .insertDate:
      return EditorTextOperations.insertDate(in: text, selectedRange: selectedRange, date: now)
    case .insertDateTime:
      return EditorTextOperations.insertDateTime(in: text, selectedRange: selectedRange, date: now)
    }
  }

  private var isJapanese: Bool {
    UserDefaults.standard.string(forKey: "appLanguage") == AppLanguage.japanese.rawValue
  }
}
