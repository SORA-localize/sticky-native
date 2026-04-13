import SwiftUI

struct MemoEditorView: View {
  @ObservedObject var memo: MemoWindow
  @ObservedObject var uiState: MemoWindowUIState
  @EnvironmentObject private var appSettings: AppSettings

  @FocusState private var isEditorFocused: Bool

  var body: some View {
    TextEditor(text: $memo.draft)
      .font(.system(size: appSettings.editorFontSize))
      .focused($isEditorFocused)
      .scrollContentBackground(.hidden)
      .padding(14)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(Color.white.opacity(0.12))
      )
      .onAppear {
        focusEditor()
      }
      .onChange(of: uiState.focusToken) { _, _ in
        focusEditor()
      }
  }

  private func focusEditor() {
    DispatchQueue.main.async {
      isEditorFocused = true
    }
  }
}
