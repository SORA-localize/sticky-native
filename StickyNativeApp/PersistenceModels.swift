import Foundation

struct PersistedMemo {
  let id: UUID
  let draft: String
  let title: String
  let originX: Double?
  let originY: Double?
  let width: Double?
  let height: Double?
  let colorIndex: Int
  let isPinned: Bool
  let isListPinned: Bool
  let isOpen: Bool
  let isTrash: Bool
  let createdAt: Date?
  let updatedAt: Date
  let sessionID: UUID?
}

struct Session {
  let id: UUID
  let name: String
  let createdAt: Date
  let updatedAt: Date
}
