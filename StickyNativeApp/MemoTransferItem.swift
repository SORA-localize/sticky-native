import UniformTypeIdentifiers
import CoreTransferable

struct MemoTransferItem: Transferable, Codable {
  let id: UUID

  static var transferRepresentation: some TransferRepresentation {
    CodableRepresentation(contentType: .memoItem)
  }
}

extension UTType {
  static let memoItem = UTType(exportedAs: "com.stickynative.memo-item")
}
