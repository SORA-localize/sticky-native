import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
  @Published var memos: [PersistedMemo] = []
  @Published var trashedMemos: [PersistedMemo] = []

  private let coordinator: PersistenceCoordinator

  init(coordinator: PersistenceCoordinator) {
    self.coordinator = coordinator
  }

  func reload() {
    memos = coordinator.fetchAllMemos()
    trashedMemos = coordinator.fetchTrashedMemos()
  }
}
