# UX Principles

最終更新: 2026-04-11

## 原則

- 速い: 起動済みなら 3 秒以内に書き始められる
- 自然: macOS window として素直に振る舞う
- 可逆: close しても失わない
- 軽い: 整理や mode 切替を先に要求しない
- 明快: pin / close / reopen の意味が曖昧でない

## 操作

- `Cmd+Option+Enter`: 新規 memo
- `Cmd+S`: 保存
- `Cmd+W`: close
- `Cmd+Enter`: 保存して close
- menu bar 1 click: reopen / focus

## 表示ルール

- `1 memo = 1 window`
- overlay / through は採用しない
- window はタイトルバーを薄くしたクロームレス寄り
- 必要な自然さを壊す場合は AppKit 標準挙動を優先する
