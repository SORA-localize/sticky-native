import AppKit
import SwiftUI

private struct SmartLinkRange {
  let range: NSRange
  let url: URL
}

private final class SmartLinkDetector {
  private let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

  func links(in text: String) -> [SmartLinkRange] {
    guard let detector else { return [] }
    let nsText = text as NSString
    let fullRange = NSRange(location: 0, length: nsText.length)
    return detector
      .matches(in: text, options: [], range: fullRange)
      .compactMap { result in
        guard let url = result.url else { return nil }
        return SmartLinkRange(range: result.range, url: url)
      }
  }
}

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
    scrollView.hasVerticalScroller = false
    scrollView.autohidesScrollers = false
    scrollView.contentView.postsBoundsChangedNotifications = true

    let textView = CheckboxNSTextView()
    textView.string = text
    textView.delegate = context.coordinator
    textView.onPerformCommand = { [weak coordinator = context.coordinator] command, textView in
      coordinator?.perform(command, in: textView)
    }
    textView.onFocusChange = onFocusChange
    configureInitialTextView(textView)

    scrollView.documentView = textView
    context.coordinator.textView = textView
    context.coordinator.focusToken = focusToken
    context.coordinator.observeBounds(of: scrollView)
    applyDynamicConfiguration(scrollView: scrollView, textView: textView, coordinator: context.coordinator)
    context.coordinator.refreshSmartLinks(in: textView)
    DispatchQueue.main.async {
      self.applyTextContainerWidth(scrollView: scrollView, textView: textView, coordinator: context.coordinator)
      textView.window?.makeFirstResponder(textView)
    }
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? CheckboxNSTextView else { return }
    context.coordinator.parent = self
    context.coordinator.observeBounds(of: scrollView)
    applyDynamicConfiguration(scrollView: scrollView, textView: textView, coordinator: context.coordinator)

    if !textView.hasMarkedText(), textView.string != text {
      let selectedRange = textView.selectedRange()
      textView.string = text
      textView.setSelectedRange(clampedRange(selectedRange, in: text))
    }
    context.coordinator.refreshSmartLinks(in: textView)

    if context.coordinator.focusToken != focusToken {
      context.coordinator.focusToken = focusToken
      DispatchQueue.main.async {
        textView.window?.makeFirstResponder(textView)
      }
    }
  }

  private func configureInitialTextView(_ textView: CheckboxNSTextView) {
    textView.isRichText = false
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.allowsUndo = true
    textView.drawsBackground = false
    textView.textColor = .labelColor
    textView.insertionPointColor = .labelColor
    textView.textContainerInset = NSSize(width: 14, height: 14)
    textView.minSize = NSSize(width: 0, height: 0)
    textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]
    textView.textContainer?.lineFragmentPadding = 0
    textView.textContainer?.widthTracksTextView = false
  }

  private func applyDynamicConfiguration(
    scrollView: NSScrollView,
    textView: CheckboxNSTextView,
    coordinator: Coordinator
  ) {
    if coordinator.appliedFontSize != fontSize {
      textView.font = .systemFont(ofSize: fontSize)
      coordinator.appliedFontSize = fontSize
    }

    applyTextContainerWidth(scrollView: scrollView, textView: textView, coordinator: coordinator)
  }

  private func applyTextContainerWidth(
    scrollView: NSScrollView,
    textView: CheckboxNSTextView,
    coordinator: Coordinator
  ) {
    let horizontalInset = textView.textContainerInset.width * 2
    let availableTextWidth = max(0, scrollView.contentView.bounds.width - horizontalInset)
    guard coordinator.appliedTextContainerWidth != availableTextWidth else { return }
    textView.textContainer?.containerSize = NSSize(
      width: availableTextWidth,
      height: CGFloat.greatestFiniteMagnitude
    )
    coordinator.appliedTextContainerWidth = availableTextWidth
  }

  private func clampedRange(_ range: NSRange, in text: String) -> NSRange {
    let length = (text as NSString).length
    return NSRange(location: min(range.location, length), length: min(range.length, max(0, length - range.location)))
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: CheckableTextView
    weak var textView: CheckboxNSTextView?
    var focusToken: UUID?
    var appliedFontSize: Double?
    var appliedTextContainerWidth: CGFloat?
    weak var observedContentView: NSClipView?
    private var boundsObserver: NSObjectProtocol?
    private let smartLinkDetector = SmartLinkDetector()

    init(_ parent: CheckableTextView) {
      self.parent = parent
    }

    deinit {
      removeBoundsObserver()
    }

    func observeBounds(of scrollView: NSScrollView) {
      let contentView = scrollView.contentView
      guard observedContentView !== contentView else { return }
      removeBoundsObserver()
      contentView.postsBoundsChangedNotifications = true
      observedContentView = contentView
      boundsObserver = NotificationCenter.default.addObserver(
        forName: NSView.boundsDidChangeNotification,
        object: contentView,
        queue: .main
      ) { [weak self, weak scrollView] _ in
        guard let self, let scrollView, let textView = self.textView else { return }
        self.parent.applyTextContainerWidth(scrollView: scrollView, textView: textView, coordinator: self)
      }
    }

    private func removeBoundsObserver() {
      if let boundsObserver {
        NotificationCenter.default.removeObserver(boundsObserver)
      }
      boundsObserver = nil
      observedContentView = nil
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? CheckboxNSTextView else { return }
      parent.text = textView.string
      refreshSmartLinks(in: textView)
    }

    func textDidBeginEditing(_ notification: Notification) {
      parent.onFocusChange(true)
    }

    func textDidEndEditing(_ notification: Notification) {
      parent.onFocusChange(false)
    }

    func perform(_ command: EditorCommand, in textView: NSTextView) {
      guard !textView.hasMarkedText() else { return }
      guard let edit = command.makeTextEdit(in: textView.string, selectedRange: textView.selectedRange()) else {
        return
      }
      guard textView.shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return }
      textView.textStorage?.replaceCharacters(in: edit.range, with: edit.replacement)
      textView.didChangeText()
      textView.setSelectedRange(edit.selectedRange)
      if let checkboxTextView = textView as? CheckboxNSTextView {
        refreshSmartLinks(in: checkboxTextView)
      }
    }

    func refreshSmartLinks(in textView: CheckboxNSTextView) {
      guard !textView.hasMarkedText() else { return }
      textView.refreshSmartLinks(using: smartLinkDetector)
    }
  }
}

final class CheckboxNSTextView: NSTextView {
  var onPerformCommand: ((EditorCommand, NSTextView) -> Void)?
  var onFocusChange: ((Bool) -> Void)?
  private var detectedLinks: [SmartLinkRange] = []

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
    if !hasMarkedText(), let command = EditorCommand.allCases.first(where: { $0.matches(event) }) {
      perform(command)
      return
    }
    super.keyDown(with: event)
  }

  override func menu(for event: NSEvent) -> NSMenu? {
    let menu = NSMenu()

    if let url = url(for: event) {
      let openItem = NSMenuItem(title: "リンクを開く", action: #selector(openSmartLink(_:)), keyEquivalent: "")
      openItem.target = self
      openItem.representedObject = url
      menu.addItem(openItem)

      let copyItem = NSMenuItem(title: "リンクをコピー", action: #selector(copySmartLink(_:)), keyEquivalent: "")
      copyItem.target = self
      copyItem.representedObject = url
      menu.addItem(copyItem)
      menu.addItem(.separator())
    }

    for command in EditorCommand.contextMenuCommands {
      let item = NSMenuItem(title: command.menuTitle, action: #selector(performEditorCommand(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = command.rawValue
      menu.addItem(item)
    }

    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "切り取り", action: #selector(cut(_:)), keyEquivalent: ""))
    menu.addItem(NSMenuItem(title: "コピー", action: #selector(copy(_:)), keyEquivalent: ""))
    menu.addItem(NSMenuItem(title: "ペースト", action: #selector(paste(_:)), keyEquivalent: ""))
    menu.addItem(.separator())
    menu.addItem(NSMenuItem(title: "すべて選択", action: #selector(selectAll(_:)), keyEquivalent: ""))

    return menu
  }

  override func mouseDown(with event: NSEvent) {
    if toggleCheckboxIfNeeded(for: event) {
      return
    }
    if openSmartLinkIfNeeded(for: event) {
      return
    }
    super.mouseDown(with: event)
  }

  override func otherMouseDown(with event: NSEvent) {
    if event.buttonNumber == 2, openSmartLink(at: event) {
      return
    }
    super.otherMouseDown(with: event)
  }

  fileprivate func refreshSmartLinks(using detector: SmartLinkDetector) {
    let textLength = (string as NSString).length
    let fullTextRange = NSRange(location: 0, length: textLength)

    if textLength > 0, let layoutManager {
      layoutManager.removeTemporaryAttribute(.underlineStyle, forCharacterRange: fullTextRange)
      layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: fullTextRange)
    }

    detectedLinks = detector.links(in: string)

    guard textLength > 0, let layoutManager else { return }
    let attributes: [NSAttributedString.Key: Any] = [
      .underlineStyle: NSUnderlineStyle.single.rawValue,
      .foregroundColor: NSColor.linkColor,
    ]
    for link in detectedLinks where NSMaxRange(link.range) <= textLength {
      layoutManager.addTemporaryAttributes(attributes, forCharacterRange: link.range)
    }
  }

  @objc private func performEditorCommand(_ sender: NSMenuItem) {
    guard
      let rawValue = sender.representedObject as? String,
      let command = EditorCommand(rawValue: rawValue)
    else { return }
    perform(command)
  }

  private func perform(_ command: EditorCommand) {
    onPerformCommand?(command, self)
  }

  private func toggleCheckboxIfNeeded(for event: NSEvent) -> Bool {
    guard let index = characterIndex(for: event) else { return false }
    guard index < (string as NSString).length else { return false }
    let character = (string as NSString).substring(with: NSRange(location: index, length: 1))
    guard character == "☐" || character == "☑" else { return false }
    setSelectedRange((string as NSString).lineRange(for: NSRange(location: index, length: 0)))
    onPerformCommand?(.toggleCheckbox, self)
    return true
  }

  private func characterIndex(for event: NSEvent) -> Int? {
    guard let layoutManager, let textContainer else { return nil }
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
    return index < (string as NSString).length ? index : nil
  }

  private func url(for event: NSEvent) -> URL? {
    guard let index = characterIndex(for: event) else { return nil }
    return url(at: index)
  }

  private func url(at characterIndex: Int) -> URL? {
    detectedLinks.first { link in
      characterIndex >= link.range.location && characterIndex < NSMaxRange(link.range)
    }?.url
  }

  private func openSmartLinkIfNeeded(for event: NSEvent) -> Bool {
    guard event.modifierFlags.contains(.command) else {
      return false
    }
    return openSmartLink(at: event)
  }

  private func openSmartLink(at event: NSEvent) -> Bool {
    guard let url = url(for: event) else { return false }
    NSWorkspace.shared.open(url)
    return true
  }

  @objc private func openSmartLink(_ sender: NSMenuItem) {
    guard let url = sender.representedObject as? URL else { return }
    NSWorkspace.shared.open(url)
  }

  @objc private func copySmartLink(_ sender: NSMenuItem) {
    guard let url = sender.representedObject as? URL else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(url.absoluteString, forType: .string)
  }
}
