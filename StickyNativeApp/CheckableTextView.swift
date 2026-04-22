import AppKit
import SwiftUI

private struct SmartLinkRange {
  let range: NSRange
  let url: URL
}

private struct MarkdownLiteDecoration {
  let range: NSRange
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

private enum MarkdownLiteParser {
  static func completedTaskLineDecorations(in text: String) -> [MarkdownLiteDecoration] {
    let nsText = text as NSString
    var decorations: [MarkdownLiteDecoration] = []
    var location = 0

    while location < nsText.length {
      let lineRange = nsText.lineRange(for: NSRange(location: location, length: 0))
      let visibleRange = visibleLineRange(from: lineRange, in: nsText)
      if visibleRange.length > 0 {
        let line = nsText.substring(with: visibleRange)
        let body = line.drop { $0 == " " || $0 == "\t" }
        if body.hasPrefix("☑") {
          decorations.append(MarkdownLiteDecoration(range: visibleRange))
        }
      }

      let nextLocation = NSMaxRange(lineRange)
      guard nextLocation > location else { break }
      location = nextLocation
    }

    return decorations
  }

  private static func visibleLineRange(from lineRange: NSRange, in text: NSString) -> NSRange {
    var length = lineRange.length
    while length > 0 {
      let character = text.substring(with: NSRange(location: lineRange.location + length - 1, length: 1))
      guard character == "\n" || character == "\r" else { break }
      length -= 1
    }
    return NSRange(location: lineRange.location, length: length)
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
    context.coordinator.refreshEditorDecorations(in: textView)
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
    context.coordinator.refreshEditorDecorations(in: textView)

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
      textView.refreshSmartLinkHoverFromLastMouseLocation()
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
        textView.refreshSmartLinkHoverFromLastMouseLocation()
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
      refreshEditorDecorations(in: textView)
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
        refreshEditorDecorations(in: checkboxTextView)
      }
    }

    func refreshEditorDecorations(in textView: CheckboxNSTextView) {
      guard !textView.hasMarkedText() else { return }
      textView.refreshMarkdownLiteDecorations()
      textView.refreshSmartLinks(using: smartLinkDetector)
    }
  }
}

final class CheckboxNSTextView: NSTextView {
  var onPerformCommand: ((EditorCommand, NSTextView) -> Void)?
  var onFocusChange: ((Bool) -> Void)?
  private var detectedLinks: [SmartLinkRange] = []
  private var hoveredLinkRange: NSRange?
  private var hoveredLinkURL: URL?
  private var linkTrackingArea: NSTrackingArea?
  private var lastMouseLocationInWindow: NSPoint?

  private static let linkAttributeKeys: [NSAttributedString.Key] = [
    .underlineStyle,
    .foregroundColor,
  ]

  private static let baseLinkAttributes: [NSAttributedString.Key: Any] = [
    .underlineStyle: NSUnderlineStyle.single.rawValue,
    .foregroundColor: NSColor.linkColor,
  ]

  private static let hoverLinkAttributes: [NSAttributedString.Key: Any] = [
    .underlineStyle: NSUnderlineStyle.thick.rawValue,
    .foregroundColor: NSColor.controlAccentColor,
  ]

  private static let markdownLiteAttributeKeys: [NSAttributedString.Key] = [
    .strikethroughStyle,
  ]

  private static let completedTaskLineAttributes: [NSAttributedString.Key: Any] = [
    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
  ]

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

  override func updateTrackingAreas() {
    if let linkTrackingArea {
      removeTrackingArea(linkTrackingArea)
    }

    let trackingArea = NSTrackingArea(
      rect: .zero,
      options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
    linkTrackingArea = trackingArea

    super.updateTrackingAreas()
  }

  override func mouseMoved(with event: NSEvent) {
    lastMouseLocationInWindow = event.locationInWindow
    refreshSmartLinkHover(at: event.locationInWindow)
    super.mouseMoved(with: event)
  }

  override func mouseExited(with event: NSEvent) {
    clearSmartLinkHover()
    super.mouseExited(with: event)
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
    detectedLinks = detector.links(in: string)
    refreshSmartLinkHoverFromLastMouseLocation()
  }

  fileprivate func refreshMarkdownLiteDecorations() {
    let textLength = (string as NSString).length
    guard textLength > 0, let layoutManager else { return }
    let fullTextRange = NSRange(location: 0, length: textLength)

    for key in Self.markdownLiteAttributeKeys {
      layoutManager.removeTemporaryAttribute(key, forCharacterRange: fullTextRange)
    }

    for decoration in MarkdownLiteParser.completedTaskLineDecorations(in: string)
      where NSMaxRange(decoration.range) <= textLength {
      layoutManager.addTemporaryAttributes(Self.completedTaskLineAttributes, forCharacterRange: decoration.range)
    }
  }

  fileprivate func refreshSmartLinkHoverFromLastMouseLocation() {
    refreshSmartLinkHover(at: lastMouseLocationInWindow)
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
    characterIndex(at: event.locationInWindow)
  }

  private func characterIndex(at pointInWindow: NSPoint) -> Int? {
    guard let layoutManager, let textContainer else { return nil }
    let pointInView = convert(pointInWindow, from: nil)
    let textOrigin = textContainerOrigin
    let pointInContainer = NSPoint(
      x: pointInView.x - textOrigin.x,
      y: pointInView.y - textOrigin.y
    )
    guard isPointInLaidOutText(pointInContainer, layoutManager: layoutManager, textContainer: textContainer) else {
      return nil
    }
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

  private func smartLink(at pointInWindow: NSPoint) -> SmartLinkRange? {
    guard let index = characterIndex(at: pointInWindow) else { return nil }
    return detectedLinks.first { link in
      index >= link.range.location && index < NSMaxRange(link.range)
    }
  }

  private func refreshSmartLinkHover(at pointInWindow: NSPoint?) {
    guard !hasMarkedText() else { return }
    guard let pointInWindow else {
      clearSmartLinkHover()
      return
    }

    let hoveredLink = smartLink(at: pointInWindow)
    hoveredLinkRange = hoveredLink?.range
    hoveredLinkURL = hoveredLink?.url
    applySmartLinkAttributes()
    updateSmartLinkCursor(at: pointInWindow)
  }

  private func clearSmartLinkHover() {
    hoveredLinkRange = nil
    hoveredLinkURL = nil
    applySmartLinkAttributes()
  }

  private func applySmartLinkAttributes() {
    let textLength = (string as NSString).length
    guard textLength > 0, let layoutManager else { return }
    let fullTextRange = NSRange(location: 0, length: textLength)

    for key in Self.linkAttributeKeys {
      layoutManager.removeTemporaryAttribute(key, forCharacterRange: fullTextRange)
    }

    for link in detectedLinks where NSMaxRange(link.range) <= textLength {
      layoutManager.addTemporaryAttributes(Self.baseLinkAttributes, forCharacterRange: link.range)
    }

    guard let hoveredLinkRange, NSMaxRange(hoveredLinkRange) <= textLength else {
      self.hoveredLinkRange = nil
      hoveredLinkURL = nil
      return
    }
    layoutManager.addTemporaryAttributes(Self.hoverLinkAttributes, forCharacterRange: hoveredLinkRange)
  }

  private func updateSmartLinkCursor(at pointInWindow: NSPoint) {
    if hoveredLinkURL != nil {
      NSCursor.pointingHand.set()
      return
    }

    let pointInView = convert(pointInWindow, from: nil)
    let pointInContainer = NSPoint(
      x: pointInView.x - textContainerOrigin.x,
      y: pointInView.y - textContainerOrigin.y
    )
    if isPointInTextContainer(pointInContainer) {
      NSCursor.iBeam.set()
    }
  }

  private func isPointInLaidOutText(
    _ point: NSPoint,
    layoutManager: NSLayoutManager,
    textContainer: NSTextContainer
  ) -> Bool {
    guard isPointInTextContainer(point) else { return false }
    layoutManager.ensureLayout(for: textContainer)
    let hitSlop: CGFloat = 3
    let usedRect = layoutManager.usedRect(for: textContainer).insetBy(dx: -hitSlop, dy: -hitSlop)
    return usedRect.contains(point)
  }

  private func isPointInTextContainer(_ point: NSPoint) -> Bool {
    guard let textContainer else { return false }
    let containerSize = textContainer.containerSize
    return point.x >= 0 && point.y >= 0 && point.x <= containerSize.width && point.y <= containerSize.height
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
