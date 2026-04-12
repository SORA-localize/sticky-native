import SwiftUI

struct ProbeEditorView: View {
  private enum HoveredControl {
    case pin
    case close
  }

  let onClose: () -> Void
  let windowState: ProbeWindowState

  @State private var draft = ""
  @State private var isPinned = false
  @State private var hoveredControl: HoveredControl?
  @FocusState private var isEditorFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Circle()
          .fill(Color.white.opacity(0.55))
          .frame(width: 10, height: 10)

        Text("Seamless Window Probe")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.primary)

        Spacer()

        Button {
          isPinned.toggle()
        } label: {
          Image(systemName: isPinned ? "pin.fill" : "pin")
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

        Button {
          onClose()
        } label: {
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
      .animation(.easeOut(duration: 0.12), value: isPinned)
      .padding(.horizontal, 16)
      .padding(.top, 14)
      .padding(.bottom, 12)

      Divider()

      HStack {
        Text(isPinned ? "Pinned state toggled" : "Click pin while another app is frontmost")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
        Spacer()
        Text("Phase 1-4")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)

      TextEditor(text: $draft)
        .font(.system(size: 16))
        .focused($isEditorFocused)
        .scrollContentBackground(.hidden)
        .padding(14)
        .background(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.12))
        )
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
    .onAppear {
      DispatchQueue.main.async {
        isEditorFocused = true
      }
    }
    .onChange(of: windowState.focusTrigger) { _, _ in
      DispatchQueue.main.async {
        isEditorFocused = true
      }
    }
  }

  private var pinBackgroundColor: Color {
    if isPinned {
      return Color.white.opacity(hoveredControl == .pin ? 0.38 : 0.30)
    }

    return hoveredControl == .pin ? Color.white.opacity(0.18) : Color.clear
  }

  private var closeBackgroundColor: Color {
    hoveredControl == .close ? Color.white.opacity(0.24) : Color.white.opacity(0.14)
  }
}
