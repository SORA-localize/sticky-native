import Foundation
import SwiftUI

@MainActor
final class MemoWindowUIState: ObservableObject {
  enum VisualCue: Equatable {
    case command(CommandTheme)
    case threshold

    var color: Color {
      switch self {
      case .command(let command):
        return command.color
      case .threshold:
        return .white
      }
    }
  }

  @Published var isPinned: Bool
  @Published var isCollapsed = false
  @Published var focusToken = UUID()
  @Published var activeCue: VisualCue? = nil

  private var cueTask: Task<Void, Never>?
  private var actionTask: Task<Void, Never>?

  init(isPinned: Bool) {
    self.isPinned = isPinned
  }

  func requestEditorFocus() {
    focusToken = UUID()
  }

  func triggerFlash(_ command: CommandTheme) {
    guard activeCue != .threshold else { return }
    // 新しいコマンド入力で遅延中アクションも含めてすべてキャンセル
    cueTask?.cancel()
    actionTask?.cancel()
    // 即時出現（アニメーションなし）
    withAnimation(nil) { activeCue = .command(command) }
    cueTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled else { return }
      withAnimation(.easeOut(duration: 0.4)) {
        self.activeCue = nil
      }
    }
  }

  func triggerThresholdCue() {
    cueTask?.cancel()
    withAnimation(nil) { activeCue = .threshold }
    cueTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(140))
      guard !Task.isCancelled else { return }
      withAnimation(.easeOut(duration: 0.18)) {
        self.activeCue = nil
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
