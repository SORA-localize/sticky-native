import Foundation

@MainActor
final class ProbeWindowState: ObservableObject {
  @Published var focusTrigger = UUID()

  func requestEditorFocus() {
    focusTrigger = UUID()
  }
}
