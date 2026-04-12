import SwiftUI

struct MemoEditorView: View {
  @ObservedObject var memo: MemoWindow
  let focusToken: UUID

  @FocusState private var isEditorFocused: Bool

  var body: some View {
    TextEditor(text: $memo.draft)
      .font(.system(size: 16))
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
      .onChange(of: focusToken) { _, _ in
        focusEditor()
      }
  }

  private func focusEditor() {
    DispatchQueue.main.async {
      isEditorFocused = true
    }
  }
}
