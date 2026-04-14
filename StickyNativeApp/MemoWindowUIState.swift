import Foundation
import SwiftUI

@MainActor
final class MemoWindowUIState: ObservableObject {
  @Published var isPinned: Bool
  @Published var focusToken = UUID()
  @Published var flashCommand: CommandTheme? = nil

  private var flashTask: Task<Void, Never>?
  private var actionTask: Task<Void, Never>?

  init(isPinned: Bool) {
    self.isPinned = isPinned
  }

  func requestEditorFocus() {
    focusToken = UUID()
  }

  func triggerFlash(_ command: CommandTheme) {
    // 新しいコマンド入力で遅延中アクションも含めてすべてキャンセル
    flashTask?.cancel()
    actionTask?.cancel()
    // 即時出現（アニメーションなし）
    withAnimation(nil) { flashCommand = command }
    flashTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled else { return }
      withAnimation(.easeOut(duration: 0.4)) {
        self.flashCommand = nil
      }
    }
  }

  func scheduleAction(after ms: Int, action: @escaping @MainActor () -> Void) {
    actionTask?.cancel()
    actionTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(ms))
      guard !Task.isCancelled else { return }
      action()
    }
  }
}
