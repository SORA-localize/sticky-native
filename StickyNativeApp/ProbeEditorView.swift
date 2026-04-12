import SwiftUI

struct ProbeEditorView: View {
  let onClose: () -> Void

  @State private var draft = ""
  @State private var isPinned = false

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
        .background(isPinned ? Color.white.opacity(0.30) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

        Button {
          onClose()
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 11, weight: .bold))
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      }
      .padding(.horizontal, 16)
      .padding(.top, 14)
      .padding(.bottom, 12)

      Divider()

      HStack {
        Text(isPinned ? "Pinned state toggled" : "Click pin while another app is frontmost")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
        Spacer()
        Text("Phase 1-2")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)

      TextEditor(text: $draft)
        .font(.system(size: 16))
        .scrollContentBackground(.hidden)
        .padding(14)
        .background(Color.clear)
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
}
