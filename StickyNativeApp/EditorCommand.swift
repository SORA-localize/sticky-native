import AppKit

enum EditorCommand: String, CaseIterable {
  case toggleCheckbox

  static let contextMenuCommands: [EditorCommand] = [
    .toggleCheckbox,
  ]

  var label: String {
    switch self {
    case .toggleCheckbox:
      return "チェックボックス切り替え"
    }
  }

  var menuTitle: String {
    switch self {
    case .toggleCheckbox:
      return "Toggle Checkbox"
    }
  }

  var shortcutDisplay: String {
    switch self {
    case .toggleCheckbox:
      return "⌘ + L"
    }
  }

  var keyEquivalent: String {
    switch self {
    case .toggleCheckbox:
      return "l"
    }
  }

  var modifierFlags: NSEvent.ModifierFlags {
    switch self {
    case .toggleCheckbox:
      return .command
    }
  }

  func matches(_ event: NSEvent) -> Bool {
    guard event.charactersIgnoringModifiers?.lowercased() == keyEquivalent else {
      return false
    }
    let relevantFlags = event.modifierFlags.intersection([.command, .option, .control, .shift])
    return relevantFlags == modifierFlags
  }
}
