import Foundation

enum MemoTitleFormatter {
  private static let titleLimit = 20

  static func generatedTitle(from draft: String) -> String {
    let title = firstContentLine(from: draft)
    guard !title.isEmpty else { return "" }
    return abbreviated(title)
  }

  static func displayTitle(from draft: String) -> String {
    let title = generatedTitle(from: draft)
    return title.isEmpty ? "New Memo" : title
  }

  static func previewText(from draft: String) -> String {
    let contentLines = draft
      .components(separatedBy: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    guard contentLines.count > 1 else { return "" }
    return contentLines[1]
  }

  private static func firstContentLine(from draft: String) -> String {
    let firstLine = draft
      .components(separatedBy: "\n")
      .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
    return firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func abbreviated(_ title: String) -> String {
    guard title.count > titleLimit else { return title }
    return String(title.prefix(titleLimit)) + "..."
  }
}
