# Paste Sanitization / Home Sync / Default Language Plan

作成: 2026-04-25  
ステータス: **SUPERSEDED**

> この計画は 2026-04-26 のレビューで以下の問題が指摘されたため廃止。
>
> - A-202 の修正案が誤り（`onClosedStackChanged?()` 追加のみでは解決しない。新規メモが SQLite に未存在であることが根本原因）
> - U-201 の保持属性集合が未確定で自己矛盾
> - ガイドラインのフェーズ分割ルールに違反（3 問題を 1 計画に束ねている）
> - SSOT 未確認を「整合済み」と誤表記
>
> 代替計画:
> - U-201 → `plan-paste-sanitization.md`
> - A-202 → `plan-home-sync-on-create.md`
> - K-203 (言語デフォルト) → 実装不要。方針: 新規インストールは英語デフォルト（commit a71be12 適用済み）。既存ユーザーの設定は維持する。

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-04-25 | 初版作成。ペースト汚染・管理画面同期・デフォルト言語の 3 問題を 1 計画にまとめる |
| 2026-04-26 | レビューにより廃止。A-202 修正案の誤り・U-201 仕様未確定・フェーズ分割違反・SSOT 誤表記を理由に SUPERSEDED とし、代替計画 2 本に分離 |

---

*以下の本文は廃止前の旧案であり無効。参照・実装に使用しないこと。有効な計画は上記代替計画を参照。*

---

## 背景（旧案 / 無効）

### U-201: ペースト時に外部フォント・背景色が混入する

NotebookLM などからテキストをコピーして貼り付けると、明朝体フォントや白色背景が混入する。`CheckboxNSTextView` は `paste(_:)` を override しておらず、`NSTextView` のデフォルト動作（RTF/HTML をそのまま挿入）が走る。

### A-202: 管理画面が新規メモ作成時に自動同期されない

`HomeViewModel.reload()` のトリガーは `windowManager.onClosedStackChanged` のみ（`AppDelegate.swift:49-53`）。このコールバックは close / trash / reopen イベントで発火するが、`createNewMemoWindow()` は呼んでいない。

### K-203: デフォルト言語の英語設定は完了済みだが既存ユーザーに非適用

`AppSettings.defaultLanguage()` の fallback が `.english` に変更済み（commit `a71be12`）。既存ユーザーの `UserDefaults` には変更が反映されない。

---

## 修正フェーズ（旧案 / 無効）

> **注意: 以下は誤った修正案。実装に使用しないこと。**
>
> - Phase 1 (U-201): プレーンテキスト取得 + typing attributes 適用という方針は、ペースト時に保持すべき bold/underline も失うため自己矛盾。正しい仕様は `plan-paste-sanitization.md` を参照。
> - Phase 2 (A-202): `onClosedStackChanged?()` を追加するだけでは解決しない。新規メモは SQLite に行が存在しないため `reload()` は空振りする。正しい修正は `plan-home-sync-on-create.md` を参照。

*(旧案本文は削除済み)*
