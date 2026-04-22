import Foundation

struct EditorTextEdit {
  let range: NSRange
  let replacement: String
  let selectedRange: NSRange
}

enum EditorTextOperations {
  static func toggleCheckbox(in text: String, selectedRange: NSRange) -> EditorTextEdit? {
    let original = text as NSString
    let lineRange = checkboxLineRange(for: selectedRange, in: original)
    let lineText = original.substring(with: lineRange)
    let lines = lineText.components(separatedBy: "\n")
    let replacement = lines
      .enumerated()
      .map { index, line in
        let isTrailingEmptyLine = index == lines.count - 1 && line.isEmpty && lineText.hasSuffix("\n")
        return isTrailingEmptyLine ? line : toggledCheckboxLine(line)
      }
      .joined(separator: "\n")

    guard replacement != lineText else { return nil }
    return EditorTextEdit(
      range: lineRange,
      replacement: replacement,
      selectedRange: NSRange(location: lineRange.location, length: (replacement as NSString).length)
    )
  }

  static func insertDate(in text: String, selectedRange: NSRange, date: Date) -> EditorTextEdit? {
    insert(formattedDate(date, format: "yy/MM/dd"), in: text, selectedRange: selectedRange)
  }

  static func insertDateTime(in text: String, selectedRange: NSRange, date: Date) -> EditorTextEdit? {
    insert(formattedDate(date, format: "yy/MM/dd HH:mm"), in: text, selectedRange: selectedRange)
  }

  private static func insert(_ replacement: String, in text: String, selectedRange: NSRange) -> EditorTextEdit? {
    let textLength = (text as NSString).length
    let range = NSRange(
      location: min(selectedRange.location, textLength),
      length: min(selectedRange.length, max(0, textLength - selectedRange.location))
    )
    return EditorTextEdit(
      range: range,
      replacement: replacement,
      selectedRange: NSRange(location: range.location + (replacement as NSString).length, length: 0)
    )
  }

  private static func checkboxLineRange(for selectedRange: NSRange, in text: NSString) -> NSRange {
    guard text.length > 0 else {
      return NSRange(location: 0, length: 0)
    }

    var range = selectedRange
    if range.length > 0 && NSMaxRange(range) <= text.length {
      range.length -= 1
    }
    return text.lineRange(for: range)
  }

  private static func toggledCheckboxLine(_ line: String) -> String {
    let indentation = line.prefix { $0 == " " || $0 == "\t" }
    let body = line.dropFirst(indentation.count)
    let prefix = String(indentation)

    if body.hasPrefix("☐ ") {
      return prefix + "☑ " + String(body.dropFirst(2))
    }
    if body.hasPrefix("☑ ") {
      return prefix + String(body.dropFirst(2))
    }
    if body.hasPrefix("☐") {
      return prefix + "☑" + String(body.dropFirst())
    }
    if body.hasPrefix("☑") {
      return prefix + String(body.dropFirst())
    }
    return prefix + "☐ " + String(body)
  }

  static func wrapSelection(in text: String, selectedRange: NSRange, prefix: String, suffix: String) -> EditorTextEdit? {
    guard selectedRange.length > 0 else { return nil }
    let nsText = text as NSString
    guard NSMaxRange(selectedRange) <= nsText.length else { return nil }
    let selectedText = nsText.substring(with: selectedRange)
    let replacement = prefix + selectedText + suffix
    return EditorTextEdit(
      range: selectedRange,
      replacement: replacement,
      selectedRange: NSRange(location: selectedRange.location, length: (replacement as NSString).length)
    )
  }

  static func prefixLines(in text: String, selectedRange: NSRange, linePrefix: String) -> EditorTextEdit? {
    guard selectedRange.length > 0 else { return nil }
    let nsText = text as NSString
    guard NSMaxRange(selectedRange) <= nsText.length else { return nil }
    let lineRange = nsText.lineRange(for: selectedRange)
    let lineText = nsText.substring(with: lineRange)
    let lines = lineText.components(separatedBy: "\n")
    let replacement = lines.enumerated().map { index, line in
      (index == lines.count - 1 && line.isEmpty) ? line : linePrefix + line
    }.joined(separator: "\n")
    guard replacement != lineText else { return nil }
    return EditorTextEdit(
      range: lineRange,
      replacement: replacement,
      selectedRange: NSRange(location: lineRange.location, length: (replacement as NSString).length)
    )
  }

  private static func formattedDate(_ date: Date, format: String) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = .current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = format
    return formatter.string(from: date)
  }
}
