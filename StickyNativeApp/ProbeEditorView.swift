import SwiftUI

struct ProbeEditorView: View {
  @State private var draft = ""

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

        Text("Phase 1-1")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 16)
      .padding(.top, 14)
      .padding(.bottom, 12)

      Divider()

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
