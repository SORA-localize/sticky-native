import Foundation

struct PersistedMemo {
  let id: UUID
  let draft: String
  let title: String
  let originX: Double?
  let originY: Double?
  let width: Double?
  let height: Double?
  let isPinned: Bool
  let isOpen: Bool
  let isTrash: Bool
  let createdAt: Date?
  let updatedAt: Date
}
