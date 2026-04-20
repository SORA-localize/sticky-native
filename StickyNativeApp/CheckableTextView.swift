import AppKit
import SwiftUI

struct CheckableTextView: NSViewRepresentable {
  @Binding var text: String
  let focusToken: UUID
  let fontSize: Double
  let onFocusChange: (Bool) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true

    let textView = CheckboxNSTextView()
    textView.string = text
    textView.delegate = context.coordinator
    textView.onToggleCheckbox = { [weak coordinator = context.coordinator] textView in
      coordinator?.toggleCheckbox(in: textView)
    }
    textView.onFocusChange = onFocusChange
    configure(textView)

    scrollView.documentView = textView
    context.coordinator.textView = textView
    context.coordinator.focusToken = focusToken
    DispatchQueue.main.async {
      textView.window?.makeFirstResponder(textView)
    }
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? CheckboxNSTextView else { return }
    context.coordinator.parent = self
    configure(textView)

    if textView.string != text {
      let selectedRange = textView.selectedRange()
      textView.string = text
      textView.setSelectedRange(clampedRange(selectedRange, in: text))
    }

    if context.coordinator.focusToken != focusToken {
      context.coordinator.focusToken = focusToken
      DispatchQueue.main.async {
        textView.window?.makeFirstResponder(textView)
      }
    }
  }

  private func configure(_ textView: CheckboxNSTextView) {
    textView.isRichText = false
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.allowsUndo = true
    textView.drawsBackground = false
    textView.textColor = .labelColor
    textView.insertionPointColor = .labelColor
    textView.font = .systemFont(ofSize: fontSize)
    textView.textContainerInset = NSSize(width: 14, height: 14)
    textView.minSize = NSSize(width: 0, height: 0)
    textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.containerSize = NSSize(
      width: textView.bounds.width,
      height: CGFloat.greatestFiniteMagnitude
    )
  }

  private func clampedRange(_ range: NSRange, in text: String) -> NSRange {
    let length = (text as NSString).length
    return NSRange(location: min(range.location, length), length: min(range.length, max(0, length - range.location)))
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: CheckableTextView
    weak var textView: CheckboxNSTextView?
    var focusToken: UUID?

    init(_ parent: CheckableTextView) {
      self.parent = parent
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      parent.text = textView.string
    }

    func textDidBeginEditing(_ notification: Notification) {
      parent.onFocusChange(true)
    }

    func textDidEndEditing(_ notification: Notification) {
      parent.onFocusChange(false)
    }

    func toggleCheckbox(in textView: NSTextView) {
      let original = textView.string as NSString
      let selectedRange = textView.selectedRange()
      let lineRange = checkboxLineRange(for: selectedRange, in: original)
      let lineText = original.substring(with: lineRange)
      let lines = lineText.components(separatedBy: "\n")
      let replacement = lineText
        .components(separatedBy: "\n")
        .enumerated()
        .map { index, line in
          let isTrailingEmptyLine = index == lines.count - 1 && line.isEmpty && lineText.hasSuffix("\n")
          return isTrailingEmptyLine ? line : toggledCheckboxLine(line)
        }
        .joined(separator: "\n")

      guard replacement != lineText else { return }
      guard textView.shouldChangeText(in: lineRange, replacementString: replacement) else { return }
      textView.textStorage?.replaceCharacters(in: lineRange, with: replacement)
      textView.didChangeText()
      textView.setSelectedRange(NSRange(location: lineRange.location, length: (replacement as NSString).length))
    }

    private func checkboxLineRange(for selectedRange: NSRange, in text: NSString) -> NSRange {
      guard text.length > 0 else {
        return NSRange(location: 0, length: 0)
      }

      var range = selectedRange
      if range.length > 0 && NSMaxRange(range) <= text.length {
        range.length -= 1
      }
      return text.lineRange(for: range)
    }

    private func toggledCheckboxLine(_ line: String) -> String {
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
  }
}

final class CheckboxNSTextView: NSTextView {
  var onToggleCheckbox: ((NSTextView) -> Void)?
  var onFocusChange: ((Bool) -> Void)?

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override func becomeFirstResponder() -> Bool {
    let result = super.becomeFirstResponder()
    if result {
      onFocusChange?(true)
    }
    return result
  }

  override func resignFirstResponder() -> Bool {
    let result = super.resignFirstResponder()
    if result {
      onFocusChange?(false)
    }
    return result
  }

  override func keyDown(with event: NSEvent) {
    if let command = EditorCommand.allCases.first(where: { $0.matches(event) }) {
      perform(command)
      return
    }
    super.keyDown(with: event)
  }

  override func menu(for event: NSEvent) -> NSMenu? {
    let menu = super.menu(for: event) ?? NSMenu()
    if !menu.items.isEmpty {
      menu.addItem(.separator())
    }

    for command in EditorCommand.contextMenuCommands {
      let item = NSMenuItem(title: command.menuTitle, action: #selector(performEditorCommand(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = command.rawValue
      menu.addItem(item)
    }

    return menu
  }

  override func mouseDown(with event: NSEvent) {
    if toggleCheckboxIfNeeded(for: event) {
      return
    }
    super.mouseDown(with: event)
  }

  @objc private func performEditorCommand(_ sender: NSMenuItem) {
    guard
      let rawValue = sender.representedObject as? String,
      let command = EditorCommand(rawValue: rawValue)
    else { return }
    perform(command)
  }

  private func perform(_ command: EditorCommand) {
    switch command {
    case .toggleCheckbox:
      onToggleCheckbox?(self)
    }
  }

  private func toggleCheckboxIfNeeded(for event: NSEvent) -> Bool {
    guard let layoutManager, let textContainer else { return false }
    let pointInView = convert(event.locationInWindow, from: nil)
    let textOrigin = textContainerOrigin
    let pointInContainer = NSPoint(
      x: pointInView.x - textOrigin.x,
      y: pointInView.y - textOrigin.y
    )
    let index = layoutManager.characterIndex(
      for: pointInContainer,
      in: textContainer,
      fractionOfDistanceBetweenInsertionPoints: nil
    )
    guard index < (string as NSString).length else { return false }
    let character = (string as NSString).substring(with: NSRange(location: index, length: 1))
    guard character == "☐" || character == "☑" else { return false }
    setSelectedRange((string as NSString).lineRange(for: NSRange(location: index, length: 0)))
    onToggleCheckbox?(self)
    return true
  }
}
