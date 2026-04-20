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
      return "チェックボックス切り替え"
    case .insertDate:
      return "日付を挿入"
    case .insertDateTime:
      return "日時を挿入"
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
}
