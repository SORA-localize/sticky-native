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
      if let completedTextRange = completedTaskTextRange(in: visibleRange, text: nsText) {
        decorations.append(MarkdownLiteDecoration(range: completedTextRange))
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

  private static func completedTaskTextRange(in visibleRange: NSRange, text: NSString) -> NSRange? {
    var location = visibleRange.location
    let end = NSMaxRange(visibleRange)

    while location < end {
      let character = text.substring(with: NSRange(location: location, length: 1))
      guard character == " " || character == "\t" else { break }
      location += 1
    }

    guard location < end else { return nil }
    guard text.substring(with: NSRange(location: location, length: 1)) == "☑" else { return nil }
    location += 1

    while location < end {
      let character = text.substring(with: NSRange(location: location, length: 1))
      guard character == " " || character == "\t" else { break }
      location += 1
    }

    guard location < end else { return nil }
    return NSRange(location: location, length: end - location)
  }
}

private enum MarkdownSelectionAction: CaseIterable {
  case bold, italic, strikethrough, highlight, quote

  var symbolName: String {
    switch self {
    case .bold: return "bold"
    case .italic: return "italic"
    case .strikethrough: return "strikethrough"
    case .highlight: return "highlighter"
    case .quote: return "quote.bubble"
    }
  }

  var tooltip: String {
    switch self {
    case .bold: return "太字"
    case .italic: return "斜体"
    case .strikethrough: return "取り消し線"
    case .highlight: return "ハイライト"
    case .quote: return "引用"
    }
  }

  func apply(to text: String, selectedRange: NSRange) -> EditorTextEdit? {
    switch self {
    case .bold:
      return EditorTextOperations.wrapSelection(in: text, selectedRange: selectedRange, prefix: "**", suffix: "**")
    case .italic:
      return EditorTextOperations.wrapSelection(in: text, selectedRange: selectedRange, prefix: "*", suffix: "*")
    case .strikethrough:
      return EditorTextOperations.wrapSelection(in: text, selectedRange: selectedRange, prefix: "~~", suffix: "~~")
    case .highlight:
      return EditorTextOperations.wrapSelection(in: text, selectedRange: selectedRange, prefix: "==", suffix: "==")
    case .quote:
      return EditorTextOperations.prefixLines(in: text, selectedRange: selectedRange, linePrefix: "> ")
    }
  }
}

private final class MarkdownSelectionToolbar: NSView {
  static let preferredSize = NSSize(width: 148, height: 34)

  var onAction: ((MarkdownSelectionAction) -> Void)?

  private let stackView = NSStackView()
  private let itemActions = MarkdownSelectionAction.allCases
  private let buttons: [NSButton]

  override init(frame frameRect: NSRect) {
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
    buttons = MarkdownSelectionAction.allCases.map { action in
      let image = NSImage(systemSymbolName: action.symbolName, accessibilityDescription: action.tooltip)?
        .withSymbolConfiguration(symbolConfig)
      let button = NSButton(frame: .zero)
      button.image = image
      button.imageScaling = .scaleProportionallyDown
      button.bezelStyle = .texturedRounded
      button.isBordered = false
      button.isEnabled = true
      button.toolTip = action.tooltip
      button.setAccessibilityLabel(action.tooltip)
      button.setButtonType(.momentaryPushIn)
      button.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        button.widthAnchor.constraint(equalToConstant: 24),
        button.heightAnchor.constraint(equalToConstant: 24),
      ])
      return button
    }

    super.init(frame: frameRect)

    wantsLayer = true
    layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.96).cgColor
    layer?.cornerRadius = 7
    layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
    layer?.borderWidth = 1
    shadow = NSShadow()
    shadow?.shadowBlurRadius = 8
    shadow?.shadowOffset = NSSize(width: 0, height: -2)
    shadow?.shadowColor = NSColor.black.withAlphaComponent(0.18)

    stackView.orientation = .horizontal
    stackView.alignment = .centerY
    stackView.spacing = 4
    stackView.edgeInsets = NSEdgeInsets(top: 5, left: 6, bottom: 5, right: 6)
    stackView.translatesAutoresizingMaskIntoConstraints = false
    buttons.forEach(stackView.addArrangedSubview)
    addSubview(stackView)

    NSLayoutConstraint.activate([
      stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
      stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  required init?(coder: NSCoder) { nil }

  override var acceptsFirstResponder: Bool { false }
  override var intrinsicContentSize: NSSize { Self.preferredSize }

  func handleClick(at point: NSPoint) {
    let pointInStack = convert(point, to: stackView)
    for (index, button) in buttons.enumerated() {
      if button.frame.contains(pointInStack) {
        onAction?(itemActions[index])
        return
      }
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
      textView.refreshSelectionToolbar()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
      guard let textView = notification.object as? CheckboxNSTextView else { return }
      textView.refreshSelectionToolbar()
    }

    func textDidBeginEditing(_ notification: Notification) {
      parent.onFocusChange(true)
      guard let textView = notification.object as? CheckboxNSTextView else { return }
      textView.refreshSelectionToolbar()
    }

    func textDidEndEditing(_ notification: Notification) {
      parent.onFocusChange(false)
      guard let textView = notification.object as? CheckboxNSTextView else { return }
      textView.hideSelectionToolbar()
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
  private var selectionToolbar: MarkdownSelectionToolbar?

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
      hideSelectionToolbar()
    }
    return result
  }

  override func keyDown(with event: NSEvent) {
    if !hasMarkedText(), let command = EditorCommand.allCases.first(where: { $0.matches(event) }) {
      perform(command)
      return
    }
    super.keyDown(with: event)
    refreshSelectionToolbar()
  }

  override func cancelOperation(_ sender: Any?) {
    hideSelectionToolbar()
    super.cancelOperation(sender)
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
    let pointInView = convert(event.locationInWindow, from: nil)
    if let toolbar = selectionToolbar, !toolbar.isHidden, toolbar.frame.contains(pointInView) {
      let pointInToolbar = toolbar.convert(pointInView, from: self)
      toolbar.handleClick(at: pointInToolbar)
      return
    }
    hideSelectionToolbar()
    if toggleCheckboxIfNeeded(for: event) {
      return
    }
    if openSmartLinkIfNeeded(for: event) {
      return
    }
    super.mouseDown(with: event)
    refreshSelectionToolbar()
  }

  override func mouseDragged(with event: NSEvent) {
    super.mouseDragged(with: event)
    refreshSelectionToolbar()
  }

  override func mouseUp(with event: NSEvent) {
    super.mouseUp(with: event)
    refreshSelectionToolbar()
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

  fileprivate func refreshSelectionToolbar() {
    guard shouldShowSelectionToolbar, let toolbarFrame = selectionToolbarFrame() else {
      hideSelectionToolbar()
      return
    }

    let toolbar = selectionToolbar ?? {
      let toolbar = MarkdownSelectionToolbar(frame: .zero)
      toolbar.translatesAutoresizingMaskIntoConstraints = true
      toolbar.onAction = { [weak self] action in
        self?.applyMarkdownAction(action)
      }
      addSubview(toolbar)
      selectionToolbar = toolbar
      return toolbar
    }()

    toolbar.frame = toolbarFrame
    toolbar.isHidden = false
  }

  fileprivate func hideSelectionToolbar() {
    selectionToolbar?.isHidden = true
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

  private func applyMarkdownAction(_ action: MarkdownSelectionAction) {
    let range = selectedRange()
    guard range.length > 0, !hasMarkedText() else { return }
    guard let edit = action.apply(to: string, selectedRange: range) else { return }
    guard shouldChangeText(in: edit.range, replacementString: edit.replacement) else { return }
    textStorage?.replaceCharacters(in: edit.range, with: edit.replacement)
    didChangeText()
    setSelectedRange(edit.selectedRange)
  }

  private var shouldShowSelectionToolbar: Bool {
    guard selectedRange().length > 0 else { return false }
    guard !hasMarkedText() else { return false }
    guard window?.firstResponder === self else { return false }
    return true
  }

  private func selectionToolbarFrame() -> NSRect? {
    guard let layoutManager, let textContainer else { return nil }
    let selectedRange = selectedRange()
    guard selectedRange.length > 0 else { return nil }

    layoutManager.ensureLayout(for: textContainer)
    let glyphRange = layoutManager.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
    guard glyphRange.length > 0 else { return nil }

    var selectionRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
    selectionRect.origin.x += textContainerOrigin.x
    selectionRect.origin.y += textContainerOrigin.y
    guard isFinite(selectionRect), !selectionRect.isEmpty else { return nil }

    let toolbarSize = selectionToolbar?.intrinsicContentSize ?? MarkdownSelectionToolbar.preferredSize
    let verticalGap: CGFloat = 6
    let horizontalInset: CGFloat = 6
    let availableWidth = max(bounds.width, toolbarSize.width + horizontalInset * 2)
    let proposedX = selectionRect.midX - toolbarSize.width / 2
    let x = min(max(horizontalInset, proposedX), availableWidth - toolbarSize.width - horizontalInset)

    let proposedAboveY = selectionRect.minY - toolbarSize.height - verticalGap
    let y: CGFloat
    if proposedAboveY >= bounds.minY + verticalGap {
      y = proposedAboveY
    } else {
      y = selectionRect.maxY + verticalGap
    }

    return NSRect(origin: NSPoint(x: x, y: y), size: toolbarSize)
  }

  private func isFinite(_ rect: NSRect) -> Bool {
    rect.origin.x.isFinite &&
      rect.origin.y.isFinite &&
      rect.size.width.isFinite &&
      rect.size.height.isFinite
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
