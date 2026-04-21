# StickyNative Current Feature Summary

Updated: 2026-04-20

This document summarizes the current app capabilities and the features added in the recent editor-command implementation work. It is a local product/reference note and is not intended to be pushed unless explicitly requested.

## Current App Capabilities

### Menu Bar App

- Runs as a menu bar app.
- Creates a new memo from the menu bar icon.
- Opens the All Memos window from the menu bar icon.
- Reopens the most recently closed memo.
- Opens the keyboard shortcut reference window.
- Quits StickyNative from the menu bar icon.

### Memo Windows

- Supports multiple memo windows.
- Supports direct text editing in each memo.
- Saves memo content automatically.
- Supports manual save with `Command-S`.
- Supports save and close with `Command-Return`.
- Supports close with `Command-W`.
- Supports moving a memo to trash with `Command-Delete`.
- Supports pinning a memo window above other windows with `Command-P`.
- Supports dragging and resizing memo windows.
- Keeps memo window chrome compact when the memo title is long.

### Memo Settings

- Supports editor font size settings: small, medium, large.
- Supports default memo size settings: small, medium, large.
- Supports memo color mode settings: default, colorful.
- Exposes these settings from the menu bar icon menu.

### Memo Management

- Shows all memos in the All Memos window.
- Supports memo search.
- Supports trash view.
- Supports restoring trashed memos.
- Supports permanent deletion from trash.
- Supports session management.
- Supports assigning memos to sessions.

### Editor Basics

- Supports plain text editing.
- Supports multi-line editing.
- Supports Japanese IME input.
- Supports cut, copy, paste, and select all from the editor context menu.
- Supports undo and redo through the native text editor behavior.

## Recent Implementation Additions

### Native Text Editor Wrapper

- Replaced the SwiftUI `TextEditor` editing surface with an `NSTextView`-based `CheckableTextView`.
- Preserved text binding and autosave behavior through the existing draft update path.
- Preserved focus behavior and one-click editing behavior.

### Checkbox Editing

- Added checkbox task editing.
- `Command-L` toggles the current line or selected lines.
- Toggle cycle:
  - normal line
  - `☐` unchecked line
  - `☑` checked line
  - normal line
- Clicking `☐` or `☑` toggles that line directly.
- Multi-line selections can be toggled at once.
- Indentation is preserved when converting lines to checkbox lines.

### Date and Date-Time Insertion

- `Command-D` inserts the current date.
- `Command-Shift-D` inserts the current date and time.
- Date format: `yy/MM/dd`
- Date-time format: `yy/MM/dd HH:mm`
- If text is selected, date/date-time insertion replaces the selection.
- Date and date-time commands are also available from the editor context menu.

### Editor Command Architecture

- Added `EditorCommand` as the single source of truth for editor command identity, labels, shortcut display, shortcut matching, and context menu ordering.
- Added `EditorTextOperations` for text operations.
- Moved checkbox/date/date-time text transformation logic out of the `NSTextView` wrapper.
- Kept `CheckableTextView` focused on event handling, selection/range extraction, and applying text edits.

### Context Menus

- Simplified the editor right-click menu.
- Removed the large default macOS text context menu surface from the editor.
- Current editor context menu:
  - チェックボックス切り替え
  - 日付を挿入
  - 日時を挿入
  - 切り取り
  - コピー
  - ペースト
  - すべて選択

### Japanese Menu Labels

- Localized the menu bar icon menu labels to Japanese.
- Localized editor command context menu labels to Japanese.
- Localized the keyboard shortcut window title to Japanese.
- Kept shortcut symbols in standard macOS notation.

### Memo Title Handling

- Added `MemoTitleFormatter`.
- Unified the title-generation path used by window display and persistence.
- Generates titles from the first non-empty line of the memo.
- Empty memo display title remains `New Memo`.
- Generated titles are capped at about 20 characters and append `...` when shortened.
- The memo window header also constrains title width to prevent long titles from expanding the top bar.

## Current Keyboard Shortcuts

### Global

- `Command-Option-Return`: Create a new memo.

### Memo Window

- `Command-S`: Save.
- `Command-Return`: Save and close.
- `Command-W`: Close.
- `Command-Delete`: Move to trash.
- `Command-P`: Toggle always-on-top.
- `Command-L`: Toggle checkbox.
- `Command-D`: Insert date.
- `Command-Shift-D`: Insert date and time.

## App Store-Relevant Feature Highlights

- Menu bar memo app.
- Fast new memo creation.
- Multiple floating memo windows.
- Autosave.
- Checkbox task editing.
- Date and date-time insertion.
- Memo search and All Memos view.
- Trash and restore flow.
- Session organization.
- Adjustable font size, memo size, and color mode.
