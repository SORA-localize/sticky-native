import AppKit
import SwiftUI

struct MemoWindowView: View {
  private let controlHitSize = CGSize(width: 28, height: 28)
  private let topStripHeight: CGFloat = 34

  private enum HoveredControl {
    case pin
    case trash
    case close
    case collapse
  }

  @ObservedObject var memo: MemoWindow
  @ObservedObject var uiState: MemoWindowUIState
  let onPinToggle: () -> Void
  let onCollapseToggle: () -> Void
  let onTrash: () -> Void
  let onClose: () -> Void
  let onSave: () -> Void
  let onSaveAndClose: () -> Void

  @State private var hoveredControl: HoveredControl?
  @State private var isWindowHovered = false
  @State private var showingTrashConfirmation = false

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      topStrip

      if !uiState.isCollapsed {
        MemoEditorView(memo: memo, uiState: uiState)
          .padding(.horizontal, 8)
          .padding(.top, 2)
          .padding(.bottom, 8)
      }

      keyboardShortcuts
    }
    .frame(
      minWidth: uiState.isCollapsed ? MemoWindowController.collapsedContentSize.width : MemoWindowController.minimumContentSize.width,
      minHeight: uiState.isCollapsed ? MemoWindowController.collapsedContentSize.height : MemoWindowController.minimumContentSize.height
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(.ultraThinMaterial)
    .background(memo.colorTheme.chromeTintColor)
    .clipShape(containerShape)
    .overlay(borderOverlay)
    .overlay(flashOverlay)
    .contentShape(containerShape)
    .onHover { isHovered in
      withAnimation(.easeOut(duration: 0.16)) {
        isWindowHovered = isHovered
      }
      if !isHovered {
        hoveredControl = nil
      }
    }
    .alert(Str.trashAlertTitle, isPresented: $showingTrashConfirmation) {
      Button(Str.trashAlertConfirm) { onTrash() }
      Button(Str.trashAlertCancel, role: .cancel) {}
    }
  }

  private var topStrip: some View {
    ZStack {
      TopStripDragSurface()
        .clipShape(topStripShape)

      HStack(spacing: 8) {
        leadingControls
        Spacer(minLength: 0)
        collapseButton
      }
      .padding(.horizontal, 10)
    }
    .frame(height: topStripHeight)
    .padding(.horizontal, 8)
    .padding(.top, 6)
    .padding(.bottom, uiState.isCollapsed ? 6 : 2)
  }

  private var leadingControls: some View {
    HStack(spacing: 6) {
      iconButton(
        systemName: "xmark",
        help: Str.trashAlertCancel,
        hoveredCase: .close,
        foreground: closeForegroundColor,
        background: closeBackgroundColor,
        action: onClose
      )

      iconButton(
        systemName: uiState.isPinned ? "pin.fill" : "pin",
        help: Str.shortcutsTogglePin,
        hoveredCase: .pin,
        foreground: pinForegroundColor,
        background: pinBackgroundColor,
        action: onPinToggle
      )

      iconButton(
        systemName: "trash",
        help: Str.trashAlertConfirm,
        hoveredCase: .trash,
        foreground: trashForegroundColor,
        background: trashBackgroundColor,
        action: { showingTrashConfirmation = true }
      )
    }
    .opacity(uiState.isCollapsed ? 0 : chromeControlOpacity)
    .allowsHitTesting(!uiState.isCollapsed && chromeControlOpacity > 0.01)
  }

  private var collapseButton: some View {
    iconButton(
      systemName: uiState.isCollapsed ? "plus" : "minus",
      help: uiState.isCollapsed ? Str.expandMemo : Str.collapseMemo,
      hoveredCase: .collapse,
      foreground: collapseForegroundColor,
      background: collapseBackgroundColor,
      opacity: uiState.isCollapsed ? collapseCollapsedOpacity : chromeControlOpacity,
      action: onCollapseToggle
    )
  }

  private func iconButton(
    systemName: String,
    help: String,
    hoveredCase: HoveredControl,
    foreground: Color,
    background: Color,
    opacity: Double = 1,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 12, weight: .semibold))
        .frame(width: controlHitSize.width, height: controlHitSize.height)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .buttonStyle(.plain)
    .foregroundStyle(foreground)
    .background(background)
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .scaleEffect(hoveredControl == hoveredCase ? 1.05 : 1.0)
    .opacity(opacity)
    .help(help)
    .onHover { isHovered in
      hoveredControl = isHovered ? hoveredCase : (hoveredControl == hoveredCase ? nil : hoveredControl)
    }
  }

  private var keyboardShortcuts: some View {
    Group {
      Button(action: {
        uiState.triggerFlash(.save)
        onSave()
      }) { EmptyView() }
        .keyboardShortcut("s", modifiers: .command)
        .frame(width: 0, height: 0)
      Button(action: {
        uiState.triggerFlash(.saveAndClose)
        uiState.scheduleAction(after: 200) { onSaveAndClose() }
      }) { EmptyView() }
        .keyboardShortcut(.return, modifiers: .command)
        .frame(width: 0, height: 0)
      Button(action: {
        uiState.triggerFlash(.trash)
        uiState.scheduleAction(after: 200) { showingTrashConfirmation = true }
      }) { EmptyView() }
        .keyboardShortcut(.delete, modifiers: .command)
        .frame(width: 0, height: 0)
      Button(action: {
        uiState.triggerFlash(.close)
        uiState.scheduleAction(after: 200) { onClose() }
      }) { EmptyView() }
        .keyboardShortcut("w", modifiers: .command)
        .frame(width: 0, height: 0)
      Button(action: onPinToggle) { EmptyView() }
        .keyboardShortcut("p", modifiers: .command)
        .frame(width: 0, height: 0)
    }
  }

  private var containerShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: uiState.isCollapsed ? 20 : 18, style: .continuous)
  }

  private var topStripShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: 14, style: .continuous)
  }

  private var borderOverlay: some View {
    Group {
      if memo.colorTheme.usesPlainBorderStyle {
        containerShape
          .stroke(Color.white.opacity(0.35), lineWidth: 1)
      } else {
        containerShape
          .strokeBorder(
            Color.white.opacity(0.18)
              .blendMode(.plusLighter),
            lineWidth: 1
          )
      }
    }
  }

  private var flashOverlay: some View {
    containerShape
      .stroke(uiState.flashCommand?.color ?? .clear, lineWidth: 2)
      .shadow(color: (uiState.flashCommand?.color ?? .clear).opacity(0.7), radius: 12)
      .opacity(uiState.flashCommand != nil ? 1 : 0)
  }

  private var chromeControlOpacity: Double {
    isWindowHovered ? 1 : 0
  }

  private var collapseCollapsedOpacity: Double {
    isWindowHovered || hoveredControl == .collapse ? 1 : 0.4
  }

  private var pinForegroundColor: Color {
    if uiState.isPinned || hoveredControl == .pin {
      return Color(red: 0.10, green: 0.48, blue: 0.60)
    }

    return Color.primary.opacity(0.82)
  }

  private var pinBackgroundColor: Color {
    if uiState.isPinned {
      return Color(red: 0.31, green: 0.79, blue: 0.90).opacity(hoveredControl == .pin ? 0.24 : 0.18)
    }

    return hoveredControl == .pin ? Color(red: 0.31, green: 0.79, blue: 0.90).opacity(0.16) : Color.clear
  }

  private var trashForegroundColor: Color {
    hoveredControl == .trash ? Color.red.opacity(0.85) : Color.primary.opacity(0.55)
  }

  private var trashBackgroundColor: Color {
    hoveredControl == .trash ? Color.red.opacity(0.15) : Color.clear
  }

  private var closeForegroundColor: Color {
    hoveredControl == .close ? Color(red: 0.73, green: 0.50, blue: 0.06) : Color.primary.opacity(0.88)
  }

  private var closeBackgroundColor: Color {
    hoveredControl == .close ? Color(red: 0.96, green: 0.78, blue: 0.26).opacity(0.22) : Color.clear
  }

  private var collapseForegroundColor: Color {
    hoveredControl == .collapse ? Color.primary.opacity(0.95) : Color.primary.opacity(uiState.isCollapsed ? 0.8 : 0.72)
  }

  private var collapseBackgroundColor: Color {
    hoveredControl == .collapse ? Color.white.opacity(0.18) : Color.clear
  }
}

private struct TopStripDragSurface: NSViewRepresentable {
  func makeNSView(context: Context) -> TopStripDragView {
    TopStripDragView()
  }

  func updateNSView(_ nsView: TopStripDragView, context: Context) {}
}

private final class TopStripDragView: NSView {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override func mouseDown(with event: NSEvent) {
    window?.performDrag(with: event)
  }
}
