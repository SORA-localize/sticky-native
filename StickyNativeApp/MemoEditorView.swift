import SwiftUI

struct MemoEditorView: View {
  @ObservedObject var memo: MemoWindow
  @ObservedObject var uiState: MemoWindowUIState
  @EnvironmentObject private var appSettings: AppSettings

  var body: some View {
    CheckableTextView(
      attributedText: Binding(
        get: { memo.attributedContent },
        set: { memo.updateAttributedContent($0) }
      ),
      focusToken: uiState.focusToken,
      fontSize: appSettings.editorFontSize,
      onFocusChange: { _ in }
    )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
