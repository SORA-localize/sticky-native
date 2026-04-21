import Foundation

enum HomeScope: Equatable, Hashable {
  case all
  case pinned
  case today
  case last7Days
  case unsorted
  case trash
  case session(UUID)
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
  @Published var sessions: [Session] = []
  @Published var selectedScope: HomeScope = .all
  @Published var searchQuery = ""

  let isSessionReady: Bool
  private let coordinator: PersistenceCoordinator
  private let calendar: Calendar

  init(coordinator: PersistenceCoordinator, calendar: Calendar = .current) {
    self.coordinator = coordinator
    self.calendar = calendar
    self.isSessionReady = coordinator.isSessionReady
  }

  func reload() {
    memos = coordinator.fetchAllMemos()
    trashedMemos = coordinator.fetchTrashedMemos()
    if isSessionReady {
      sessions = coordinator.fetchAllSessions()
    }
  }

  func clearSearch() {
    searchQuery = ""
  }

  func setListPinned(id: UUID, isPinned: Bool) {
    coordinator.saveListPinned(id: id, isPinned: isPinned)
    reload()
  }

  func deleteSessionFallbackIfNeeded(id: UUID) {
    if selectedScope == .session(id) {
      selectedScope = .all
    }
  }

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

    if selectedScope == .trash || selectedScope == .pinned {
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
    case .pinned:
      return "No pinned memos"
    case .today:
      return "No memos today"
    case .last7Days:
      return "No memos in the last 7 days"
    case .unsorted:
      return "No unsorted memos"
    case .trash:
      return "Trash is empty"
    case .session:
      return "No memos in this session"
    }
  }

  func sessionName(for memo: PersistedMemo) -> String? {
    guard let sessionID = memo.sessionID else { return nil }
    return sessions.first { $0.id == sessionID }?.name
  }

  private var scopeMemos: [PersistedMemo] {
    switch selectedScope {
    case .all:
      return memos
    case .pinned:
      return memos.filter(\.isListPinned)
    case .today:
      return memos.filter { calendar.isDateInToday($0.contentEditedAt) }
    case .last7Days:
      return memos.filter { isInLastSevenDays($0.contentEditedAt) }
    case .unsorted:
      return memos.filter { $0.sessionID == nil }
    case .trash:
      return trashedMemos
    case .session(let id):
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
    if calendar.isDateInToday(date) {
      return .today
    }
    if calendar.isDateInYesterday(date) {
      return .yesterday
    }

    let startOfToday = calendar.startOfDay(for: Date())
    let startOfDate = calendar.startOfDay(for: date)
    let days = calendar.dateComponents([.day], from: startOfDate, to: startOfToday).day ?? 0

    if days <= 7 {
      return .previous7Days
    }
    if days <= 30 {
      return .previous30Days
    }
    return .earlier
  }

  private func isInLastSevenDays(_ date: Date) -> Bool {
    let startOfToday = calendar.startOfDay(for: Date())
    guard let start = calendar.date(byAdding: .day, value: -6, to: startOfToday) else {
      return false
    }
    return date >= start
  }
}

private enum DateBucket: String, CaseIterable {
  case today
  case yesterday
  case previous7Days
  case previous30Days
  case earlier

  var title: String {
    switch self {
    case .today:
      return "Today"
    case .yesterday:
      return "Yesterday"
    case .previous7Days:
      return "Previous 7 Days"
    case .previous30Days:
      return "Previous 30 Days"
    case .earlier:
      return "Earlier"
    }
  }
}

