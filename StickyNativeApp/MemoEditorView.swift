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
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(
                isEditorFocused ? Color.white.opacity(0.55) : Color.white.opacity(0.18),
                lineWidth: isEditorFocused ? 1.5 : 1
              )
          )
      )
      .onAppear {
        focusEditor()
      }
      .onChange(of: uiState.focusToken) { _, _ in
        focusEditor()
      }
      .animation(.easeInOut(duration: 0.15), value: isEditorFocused)
  }

  private func focusEditor() {
    DispatchQueue.main.async {
      isEditorFocused = true
    }
  }
}
