import Foundation

enum SessionFilter: Equatable, Hashable {
  case all
  case unsorted
  case session(UUID)
}

@MainActor
final class HomeViewModel: ObservableObject {
  @Published var memos: [PersistedMemo] = []
  @Published var trashedMemos: [PersistedMemo] = []
  @Published var sessions: [Session] = []
  @Published var selectedFilter: SessionFilter = .all

  let isSessionReady: Bool
  private let coordinator: PersistenceCoordinator

  init(coordinator: PersistenceCoordinator) {
    self.coordinator = coordinator
    self.isSessionReady = coordinator.isSessionReady
  }

  func reload() {
    memos = coordinator.fetchAllMemos()
    trashedMemos = coordinator.fetchTrashedMemos()
    if isSessionReady {
      sessions = coordinator.fetchAllSessions()
    }
  }

  var filteredMemos: [PersistedMemo] {
    switch selectedFilter {
    case .all:
      return memos
    case .unsorted:
      return memos.filter { $0.sessionID == nil }
    case .session(let id):
      return memos.filter { $0.sessionID == id }
    }
  }
}
