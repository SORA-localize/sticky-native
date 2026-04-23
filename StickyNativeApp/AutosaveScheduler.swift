import Foundation

@MainActor
final class AutosaveScheduler {
  private var pendingItems: [UUID: DispatchWorkItem] = [:]
  private let delay: TimeInterval
  private let save: (UUID, EditorContent) -> Void

  init(delay: TimeInterval = 1.5, save: @escaping (UUID, EditorContent) -> Void) {
    self.delay = delay
    self.save = save
  }

  func schedule(id: UUID, content: EditorContent) {
    pendingItems[id]?.cancel()
    let item = DispatchWorkItem { [weak self] in
      self?.save(id, content)
      self?.pendingItems.removeValue(forKey: id)
    }
    pendingItems[id] = item
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
  }

  func flush(id: UUID, content: EditorContent) {
    pendingItems[id]?.cancel()
    pendingItems.removeValue(forKey: id)
    save(id, content)
  }
}
