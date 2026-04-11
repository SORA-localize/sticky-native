# Product Vision

最終更新: 2026-04-11

## 目的

- 思考断片を即座に退避できる macOS ネイティブメモを作る
- `Cmd+Option+Enter -> すぐ書く -> 元作業に戻る -> 1 click で再編集` を主体験に置く
- `1 memo = 1 window` を表示モデルの基準にする

## 非ゴール

- 旧 `Sticky` 実装の延命
- overlay / through の再導入
- 初期段階での Home / Trash / Session 管理の作り込み
- クラウド同期、共有、AI 整理

## 初期固定事項

- app 名: `StickyNative`
- bundle id: `com.hori.StickyNative`
- minimum macOS: `14.0`
- 配布形態: ローカル開発前提の menu bar app

## 中心フロー

1. 作業中に `Cmd+Option+Enter`
2. 新しい memo window が前面に出る
3. そのまま書く
4. すぐ元の作業に戻る
5. menu bar から 1 click で再編集する
