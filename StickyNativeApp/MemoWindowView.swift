import AppKit
import SwiftUI

struct MemoWindowView: View {
  private enum HoveredControl {
    case pin
    case trash
    case close
  }

  @ObservedObject var memo: MemoWindow
  @ObservedObject var uiState: MemoWindowUIState
  let onPinToggle: () -> Void
  let onTrash: () -> Void
  let onClose: () -> Void

  @State private var hoveredControl: HoveredControl?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 12) {
        HStack(spacing: 10) {
          Circle()
            .fill(Color.white.opacity(0.55))
            .frame(width: 10, height: 10)

          Text(memo.title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary)
        }

        WindowDragHandle()
          .frame(maxWidth: .infinity)
          .frame(height: 30)

        Button(action: onPinToggle) {
          Image(systemName: uiState.isPinned ? "pin.fill" : "pin")
            .font(.system(size: 12, weight: .semibold))
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(hoveredControl == .pin ? Color.primary : Color.primary.opacity(0.88))
        .background(pinBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .scaleEffect(hoveredControl == .pin ? 1.04 : 1.0)
        .onHover { isHovered in
          hoveredControl = isHovered ? .pin : (hoveredControl == .pin ? nil : hoveredControl)
        }

        Button(action: onTrash) {
          Image(systemName: "trash")
            .font(.system(size: 11, weight: .semibold))
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(hoveredControl == .trash ? Color.red.opacity(0.85) : Color.primary.opacity(0.55))
        .background(hoveredControl == .trash ? Color.red.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .scaleEffect(hoveredControl == .trash ? 1.04 : 1.0)
        .onHover { isHovered in
          hoveredControl = isHovered ? .trash : (hoveredControl == .trash ? nil : hoveredControl)
        }

        Button(action: onClose) {
          Image(systemName: "xmark")
            .font(.system(size: 11, weight: .bold))
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(hoveredControl == .close ? Color.primary : Color.primary.opacity(0.88))
        .background(closeBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .scaleEffect(hoveredControl == .close ? 1.04 : 1.0)
        .onHover { isHovered in
          hoveredControl = isHovered ? .close : (hoveredControl == .close ? nil : hoveredControl)
        }
      }
      .animation(.easeOut(duration: 0.12), value: hoveredControl)
      .padding(.horizontal, 16)
      .padding(.top, 14)
      .padding(.bottom, 12)

      MemoEditorView(memo: memo, uiState: uiState)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    .frame(minWidth: 420, minHeight: 280)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(Color.white.opacity(0.35), lineWidth: 1)
    )
    .padding(10)
  }

  private var pinBackgroundColor: Color {
    if uiState.isPinned {
      return Color.white.opacity(hoveredControl == .pin ? 0.38 : 0.30)
    }

    return hoveredControl == .pin ? Color.white.opacity(0.18) : Color.clear
  }

  private var closeBackgroundColor: Color {
    hoveredControl == .close ? Color.white.opacity(0.24) : Color.white.opacity(0.14)
  }
}

private struct WindowDragHandle: NSViewRepresentable {
  func makeNSView(context: Context) -> WindowDragHandleView {
    WindowDragHandleView()
  }

  func updateNSView(_ nsView: WindowDragHandleView, context: Context) {}
}

private final class WindowDragHandleView: NSView {
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
