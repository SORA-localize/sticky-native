import SwiftUI

struct MemoEditorView: View {
  @ObservedObject var memo: MemoWindow
  @ObservedObject var uiState: MemoWindowUIState
  @EnvironmentObject private var appSettings: AppSettings

  @State private var isEditorFocused = false

  var body: some View {
    CheckableTextView(
      attributedText: Binding(
        get: { memo.attributedContent },
        set: { memo.updateAttributedContent($0) }
      ),
      focusToken: uiState.focusToken,
      fontSize: appSettings.editorFontSize,
      onFocusChange: { isEditorFocused = $0 }
    )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(memo.colorTheme.editorTintColor)
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(
                isEditorFocused ? Color.white.opacity(0.55) : Color.white.opacity(0.18),
                lineWidth: isEditorFocused ? 1.5 : 1
              )
          )
      )
      .animation(.easeInOut(duration: 0.15), value: isEditorFocused)
  }
}
