import Foundation

enum HomeScope: Equatable, Hashable {
  case all
  case trash
  case folder(UUID)
}

struct MemoListSection: Identifiable {
  let id: String
  let title: String
  let memos: [PersistedMemo]
}

@MainActor
final class HomeViewModel: ObservableObject {
  @Published var memos: [PersistedMemo] = []
  @Published var trashedMemos: [PersistedMemo] = []
  @Published var folders: [Folder] = []
  @Published var selectedScope: HomeScope = .all
  @Published var searchQuery = ""

  let isFolderReady: Bool
  private let coordinator: PersistenceCoordinator
  private let calendar: Calendar

  init(coordinator: PersistenceCoordinator, calendar: Calendar = .current) {
    self.coordinator = coordinator
    self.calendar = calendar
    self.isFolderReady = coordinator.isFolderReady
  }

  func reload() {
    memos = coordinator.fetchAllMemos()
    trashedMemos = coordinator.fetchTrashedMemos()
    if isFolderReady {
      folders = coordinator.fetchAllFolders()
    }
  }

  func clearSearch() {
    searchQuery = ""
  }

  func setListPinned(id: UUID, isPinned: Bool) {
    coordinator.saveListPinned(id: id, isPinned: isPinned)
    reload()
  }

  func deleteFolderFallbackIfNeeded(id: UUID) {
    if selectedScope == .folder(id) {
      selectedScope = .all
    }
  }

  // MARK: - Counts

  var allMemosCount: Int {
    memos.filter { $0.sessionID == nil }.count
  }

  func folderCount(id: UUID) -> Int {
    memos.filter { $0.sessionID == id }.count
  }

  var trashCount: Int {
    trashedMemos.count
  }

  // MARK: - Sections

  var sections: [MemoListSection] {
    let scoped = sortedMemos(scopeMemos)
    let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

    if !query.isEmpty {
      let results = scoped.filter {
        $0.title.localizedCaseInsensitiveContains(query) ||
        $0.draft.localizedCaseInsensitiveContains(query)
      }
      return results.isEmpty ? [] : [MemoListSection(id: "search", title: "Search Results", memos: results)]
    }

    if selectedScope == .trash {
      return dateSections(for: scoped)
    }

    let pinned = scoped.filter(\.isListPinned)
    let unpinned = scoped.filter { !$0.isListPinned }
    var result: [MemoListSection] = []
    if !pinned.isEmpty {
      result.append(MemoListSection(id: "pinned", title: "Pinned", memos: pinned))
    }
    result.append(contentsOf: dateSections(for: unpinned))
    return result
  }

  var emptyMessage: String {
    if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return "No results"
    }
    switch selectedScope {
    case .all:
      return "No memos"
    case .trash:
      return "Trash is empty"
    case .folder:
      return "No memos in this folder"
    }
  }

  private var scopeMemos: [PersistedMemo] {
    switch selectedScope {
    case .all:
      return memos.filter { $0.sessionID == nil }
    case .trash:
      return trashedMemos
    case .folder(let id):
      return memos.filter { $0.sessionID == id }
    }
  }

  private func sortedMemos(_ memos: [PersistedMemo]) -> [PersistedMemo] {
    memos.sorted { lhs, rhs in
      if lhs.contentEditedAt == rhs.contentEditedAt {
        return lhs.id.uuidString < rhs.id.uuidString
      }
      return lhs.contentEditedAt > rhs.contentEditedAt
    }
  }

  private func dateSections(for memos: [PersistedMemo]) -> [MemoListSection] {
    var buckets: [DateBucket: [PersistedMemo]] = [:]
    for memo in memos {
      buckets[bucket(for: memo.contentEditedAt), default: []].append(memo)
    }
    return DateBucket.allCases.compactMap { bucket in
      guard let memos = buckets[bucket], !memos.isEmpty else { return nil }
      return MemoListSection(id: bucket.rawValue, title: bucket.title, memos: sortedMemos(memos))
    }
  }

  private func bucket(for date: Date) -> DateBucket {
    if calendar.isDateInToday(date) { return .today }
    if calendar.isDateInYesterday(date) { return .yesterday }
    let days = calendar.dateComponents(
      [.day],
      from: calendar.startOfDay(for: date),
      to: calendar.startOfDay(for: Date())
    ).day ?? 0
    if days <= 7 { return .previous7Days }
    if days <= 30 { return .previous30Days }
    return .earlier
  }
}

private enum DateBucket: String, CaseIterable {
  case today, yesterday, previous7Days, previous30Days, earlier

  var title: String {
    switch self {
    case .today: return "Today"
    case .yesterday: return "Yesterday"
    case .previous7Days: return "Previous 7 Days"
    case .previous30Days: return "Previous 30 Days"
    case .earlier: return "Earlier"
    }
  }
}
