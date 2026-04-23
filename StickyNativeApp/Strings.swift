import Foundation

@MainActor
struct Str {
  private static var isJa: Bool { AppSettings.shared.language == .japanese }

  // MARK: - Menu: Memo section
  static var menuSectionMemo:     String { isJa ? "メモ"                    : "Memo" }
  static var menuNewMemo:         String { isJa ? "新規メモ"                 : "New Memo" }
  static var menuReopenLast:      String { isJa ? "最後に閉じたメモを開く"      : "Reopen Last Closed" }

  // MARK: - Menu: Settings section
  static var menuSectionSettings: String { isJa ? "設定"                    : "Settings" }
  static var menuLanguage:        String { isJa ? "言語"                    : "Language" }
  static var menuQuit:            String { isJa ? "StickyNativeを終了"       : "Quit StickyNative" }

  // MARK: - Size labels (menu + settings shared)
  static var sizeSmall:           String { isJa ? "小"                     : "Small" }
  static var sizeMedium:          String { isJa ? "中"                     : "Medium" }
  static var sizeLarge:           String { isJa ? "大"                     : "Large" }

  // MARK: - Color labels (menu + settings shared)
  static var colorDefault:        String { isJa ? "デフォルト"               : "Default" }
  static var colorColorful:       String { isJa ? "カラフル"                 : "Colorful" }

  // MARK: - Section labels (menu + settings shared)
  static var labelFontSize:       String { isJa ? "文字サイズ"               : "Font Size" }
  static var labelMemoSize:       String { isJa ? "メモサイズ"               : "Memo Size" }
  static var labelMemoColor:      String { isJa ? "メモカラー"               : "Memo Color" }
  static var labelHotkeys:        String { isJa ? "ショートカット"            : "Hotkeys" }

  // MARK: - Home: Sidebar
  static var allMemos:            String { isJa ? "すべてのメモ"              : "All Memos" }
  static var trash:               String { isJa ? "ゴミ箱"                  : "Trash" }
  static var newFolder:           String { isJa ? "新規フォルダ"              : "New Folder" }
  static var folderManagement:    String { isJa ? "フォルダ管理"              : "Manage Folders" }
  static var folders:             String { isJa ? "フォルダ"                 : "Folders" }
  static var hideSidebar:         String { isJa ? "サイドバーを隠す"           : "Hide Sidebar" }
  static var showSidebar:         String { isJa ? "サイドバーを表示"           : "Show Sidebar" }
  static var folderLabel:         String { isJa ? "フォルダ"                 : "Folder" }

  // MARK: - Home: Header
  static var search:              String { isJa ? "検索"                    : "Search" }
  static var emptyTrash:          String { isJa ? "ゴミ箱を空にする"           : "Empty Trash" }

  // MARK: - Home: Memo count
  static var memoSingular:        String { isJa ? "件"                     : "memo" }
  static var memoPlural:          String { isJa ? "件"                     : "memos" }

  // MARK: - Home: Folder Manager
  static var done:                String { isJa ? "完了"                    : "Done" }
  static var delete:              String { isJa ? "削除"                    : "Delete" }
  static var deleteFolderAlertTitle: String {
    isJa ? "このフォルダを削除しますか？" : "Delete this folder?"
  }
  static var deleteFolderAlertMessage: String {
    isJa ? "中のメモはすべてのメモに移動します。" : "Memos in this folder will move to All Memos."
  }

  // MARK: - Home: Context menu
  static var restore:             String { isJa ? "元に戻す"                 : "Restore" }
  static var pinInList:           String { isJa ? "リストにピン留め"            : "Pin in List" }
  static var unpinFromList:       String { isJa ? "ピン留めを解除"             : "Unpin from List" }
  static var moveToTrash:         String { isJa ? "ゴミ箱に移す"              : "Move to Trash" }
  static var removeFromFolder:    String { isJa ? "フォルダから削除"            : "Remove from Folder" }
  static var moveToFolder:        String { isJa ? "フォルダに移動"             : "Move to Folder" }

  // MARK: - Home: Empty states
  static var noResults:           String { isJa ? "検索結果なし"              : "No results" }
  static var noMemos:             String { isJa ? "メモなし"                 : "No memos" }
  static var trashIsEmpty:        String { isJa ? "ゴミ箱は空です"             : "Trash is empty" }
  static var noMemosInFolder:     String { isJa ? "このフォルダにメモはありません" : "No memos in this folder" }
  static var untitled:            String { isJa ? "無題"                    : "Untitled" }

  // MARK: - Home: Date sections
  static var dateToday:           String { isJa ? "今日"                    : "Today" }
  static var dateYesterday:       String { isJa ? "昨日"                    : "Yesterday" }
  static var datePrevious7Days:   String { isJa ? "過去7日間"                : "Previous 7 Days" }
  static var datePrevious30Days:  String { isJa ? "過去30日間"               : "Previous 30 Days" }
  static var dateEarlier:         String { isJa ? "それ以前"                 : "Earlier" }

  // MARK: - Home: Section headers
  static var sectionSearchResults:String { isJa ? "検索結果"                 : "Search Results" }
  static var sectionPinned:       String { isJa ? "ピン留め"                 : "Pinned" }

  // MARK: - Settings
  static var settingsFontSizeHeader:  String { isJa ? "エディタのフォントサイズ"   : "Editor Font Size" }
  static var settingsMemoSizeHeader:  String { isJa ? "新規メモのデフォルトサイズ" : "Default Memo Size" }
  static var settingsMemoColorHeader: String { isJa ? "新規メモのカラー"        : "Memo Color" }
  static var settingsCustom:          String { isJa ? "カスタム"               : "Custom" }
  static var settingsColorDefaultDesc: String {
    isJa ? "新規メモを標準カラーで固定します。" : "New memos use the default color."
  }
  static var settingsColorColorfulDesc: String {
    isJa ? "新規メモを複数カラーで順番に作成します。" : "New memos cycle through multiple colors."
  }
  static var settingsHotkeysHeader:   String { isJa ? "グローバルショートカット"  : "Global Shortcuts" }
  static var settingsCreateMemo:      String { isJa ? "新規メモを作成"          : "Create New Memo" }
  static var settingsHotkeysNote:     String {
    isJa ? "カスタマイズは今後対応予定です。" : "Customization will be supported in a future update."
  }

  // MARK: - Window titles
  static var settingsWindowTitle: String { isJa ? "設定"                    : "Settings" }
  static var allMemosWindowTitle: String { isJa ? "すべてのメモ"              : "All Memos" }
  static var launching:           String { isJa ? "起動中..."                : "Launching..." }

  // MARK: - Memo window: trash alert
  static var trashAlertTitle:     String { isJa ? "このメモをゴミ箱に移しますか？" : "Move this memo to trash?" }
  static var trashAlertConfirm:   String { isJa ? "ゴミ箱に移す"              : "Move to Trash" }
  static var trashAlertCancel:    String { isJa ? "キャンセル"                : "Cancel" }

  // MARK: - Editor context menu
  static var editorBold:          String { isJa ? "太字"                    : "Bold" }
  static var editorUnderline:     String { isJa ? "下線"                    : "Underline" }
  static var editorStrikethrough: String { isJa ? "取り消し線"               : "Strikethrough" }
  static var editorOpenLink:      String { isJa ? "リンクを開く"              : "Open Link" }
  static var editorCopyLink:      String { isJa ? "リンクをコピー"            : "Copy Link" }
  static var editorCut:           String { isJa ? "切り取り"                 : "Cut" }
  static var editorCopy:          String { isJa ? "コピー"                   : "Copy" }
  static var editorPaste:         String { isJa ? "ペースト"                 : "Paste" }
  static var editorSelectAll:     String { isJa ? "すべて選択"               : "Select All" }

  // MARK: - Memo title
  static var newMemoTitle:        String { isJa ? "新規メモ"                 : "New Memo" }
}
