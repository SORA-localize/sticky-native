import Foundation

@MainActor
final class MemoWindowUIState: ObservableObject {
  @Published var isPinned: Bool
  @Published var focusToken = UUID()

  init(isPinned: Bool) {
    self.isPinned = isPinned
  }

  func requestEditorFocus() {
    focusToken = UUID()
  }
}
