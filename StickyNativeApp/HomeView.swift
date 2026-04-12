import SwiftUI

struct HomeView: View {
  @ObservedObject var viewModel: HomeViewModel
  let onOpenMemo: (UUID) -> Void
  let onTrashMemo: (UUID) -> Void
  let onRestoreMemo: (UUID) -> Void
  let onEmptyTrash: () -> Void

  @State private var searchQuery = ""
  @State private var showTrash = false

  private var displayedMemos: [PersistedMemo] {
    let list = showTrash ? viewModel.trashedMemos : viewModel.memos
    guard !searchQuery.isEmpty else { return list }
    return list.filter {
      $0.title.localizedCaseInsensitiveContains(searchQuery) ||
      $0.draft.localizedCaseInsensitiveContains(searchQuery)
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      toolbar
      searchBar
      Divider()
      memoList
    }
    .onAppear { viewModel.reload() }
  }

  // MARK: - Subviews

  private var toolbar: some View {
    HStack {
      Picker("", selection: $showTrash) {
        Text("Memos").tag(false)
        Text("Trash").tag(true)
      }
      .pickerStyle(.segmented)
      .frame(width: 160)

      Spacer()

      if showTrash && !viewModel.trashedMemos.isEmpty {
        Button("Empty Trash") { onEmptyTrash() }
          .foregroundStyle(.red)
          .buttonStyle(.plain)
          .font(.system(size: 12))
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  private var searchBar: some View {
    HStack(spacing: 6) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
        .font(.system(size: 12))
      TextField("Search", text: $searchQuery)
        .textFieldStyle(.plain)
        .font(.system(size: 13))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color(NSColor.controlBackgroundColor))
  }

  @ViewBuilder
  private var memoList: some View {
    if displayedMemos.isEmpty {
      VStack {
        Spacer()
        Text(emptyMessage)
          .foregroundStyle(.secondary)
          .font(.system(size: 13))
        Spacer()
      }
    } else {
      List(displayedMemos, id: \.id) { memo in
        MemoRowView(
          memo: memo,
          isTrashView: showTrash,
          onOpen: { onOpenMemo(memo.id) },
          onTrash: { onTrashMemo(memo.id) },
          onRestore: { onRestoreMemo(memo.id) }
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
      }
      .listStyle(.plain)
    }
  }

  private var emptyMessage: String {
    if !searchQuery.isEmpty { return "No results" }
    return showTrash ? "Trash is empty" : "No memos"
  }
}

// MARK: - Row

private struct MemoRowView: View {
  let memo: PersistedMemo
  let isTrashView: Bool
  let onOpen: () -> Void
  let onTrash: () -> Void
  let onRestore: () -> Void

  @State private var isHovered = false

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(memo.title.isEmpty ? "Untitled" : memo.title)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(memo.title.isEmpty ? .secondary : .primary)
          .lineLimit(1)

        if !memo.draft.isEmpty {
          Text(memo.draft)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 6) {
        Text(memo.updatedAt, style: .relative)
          .font(.system(size: 10))
          .foregroundStyle(.tertiary)

        if isTrashView {
          Button("Restore") { onRestore() }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
        } else {
          Button(action: onTrash) {
            Image(systemName: "trash")
              .font(.system(size: 11))
          }
          .buttonStyle(.plain)
          .foregroundStyle(.secondary)
          .opacity(isHovered ? 1 : 0)
        }
      }
      .frame(minWidth: 60, alignment: .trailing)
    }
    .contentShape(Rectangle())
    .onTapGesture { if !isTrashView { onOpen() } }
    .onHover { isHovered = $0 }
  }
}
