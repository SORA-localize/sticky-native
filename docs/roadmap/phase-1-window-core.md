# Phase 1 Window Core Note

最終更新: 2026-04-12

## 位置づけ

この文書は、`Phase 1 = Window Core` として計画していた旧案の退避メモである。
現在の SSOT では Phase 1 は [phase-1-seamless-window-probe-plan.md](/Users/hori/Desktop/StickyNative/docs/roadmap/phase-1-seamless-window-probe-plan.md:1) を正とし、本書を実装計画として参照しない。

Window Core の内容は、現行ロードマップでは主に Phase 2 と Phase 3 に再配置されている。

## 目的

`Cmd+Option+Enter -> すぐ書く -> 元作業に戻る -> 1 click で再編集` を、overlay なしの macOS native window として、かつ seamless UX 前提で成立させる。

## 成功条件

- menu bar からアプリ状態が見える
- global shortcut で新規 memo が前面に出る
- memo ごとに独立 window が作られる
- 別アプリ前面時でも 1 click で pin / close などを実行できる
- 呼び出し直後にゼロクリックで入力開始できる
- 入力、drag、resize、pin、close が自然に動く
- close 後も menu bar から 1 click で reopen できる
- app 再起動後も local draft が残る

## 実装分割

1. App shell
   - LSUIElement menu bar app
   - AppDelegate
   - status item
2. Seamless window core
   - `SeamlessWindow`
   - `SeamlessHostingView`
   - `@FocusState`
3. Window core
   - memo model
   - NSWindowController
   - SwiftUI editor view
4. Shortcut
   - Carbon hotkey 登録
   - `Cmd+Option+Enter`
5. Persistence
   - SQLite schema
   - upsert / fetch
   - window frame / pin / open state 保存
6. Reopen
   - recent memo menu
   - focus / reopen 分岐

## 非対応

- Trash
- Session
- 旧 DB import
- 複数 memo 一括操作

## human check

- header の drag 感が自然か
- pin の意味が迷わないか
- close しても不安がないか
- menu bar からの reopen が 1 click で十分か

## 現在の扱い

- 実装開始時の正計画として使わない
- 必要なら Phase 2 / Phase 3 の親メモとして内容を分解して再利用する
