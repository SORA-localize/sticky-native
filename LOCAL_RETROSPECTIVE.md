# StickyNative Local Retrospective

更新: 2026-04-15

このファイルはローカル整理用メモ。未コミットのまま使う前提。

---

## 概要

StickyNative の開発から GitHub 配布、notarization、App Store Connect 提出までの過程で、特に詰まりやすかった点を整理する。

目的は以下の3つ。

- 次回の macOS アプリ配布を早くする
- 同じ種類の詰まりを避ける
- 「何が実装問題で、何が配布・審査問題だったか」を切り分ける

---

## 全体所感

- アプリ本体の実装より、配布と審査対応の方が想像以上に重かった
- 「Xcode で動く」ことと「一般ユーザーが開ける」ことは全く別問題だった
- 「Developer ID 直配布」と「Mac App Store 提出」は似ているようで別フローだった
- App Sandbox は Xcode のチェックを入れるだけでは不十分で、entitlements の実体が必要だった

---

## 主な詰まりポイント

### 1. 配布用 `.app` とソースコード push の関係が分かりにくかった

#### 詰まった内容

- GitHub に push したらそのままアプリを落とせる感覚があった
- リポジトリの Release と、配布用バイナリの役割が最初は分離できていなかった
- `.xcodeproj` と `.app` と `.zip` のどれを配るべきか迷いがあった

#### 実際の整理

- GitHub リポジトリ本体はソースコード置き場
- ユーザー向けには Release asset として `.zip` を添付する
- 配るのは基本的に `StickyNative.app` を含む zip
- `.xcodeproj` はユーザー配布物ではない

#### 次回の教訓

- 最初に「ソース配布」と「アプリ配布」を分けて考える
- 友人配布でも、最初から Release asset を前提にすると迷いにくい

---

### 2. notarization とコード署名の関係が分かりにくかった

#### 詰まった内容

- notarization が遅いのか失敗しているのか判断しづらかった
- `Hardened Runtime`、`署名`、`timestamp`、`notarytool` の依存関係が最初は曖昧だった
- 何を直せば notary が通るのか切り分けに時間がかかった

#### 実際の原因

- app の中身が正しく `Developer ID Application` で署名されていない状態があった
- secure timestamp が入っていない build が混ざっていた
- zip の中身が古い build のままになっていたこともあった
- notarization に出す前に「最終成果物そのもの」を検証しないと混乱しやすい

#### 次回の教訓

- notarization 前に必ず以下を確認する
  - `codesign -dv --verbose=4 <app>`
  - `codesign --verify --deep --strict --verbose=4 <app>`
- zip は最後に fresh に作る
- notarization に出す対象と実際に配る対象を一致させる

---

### 3. `Developer ID` と `App Store Connect` の違いが分かりにくかった

#### 詰まった内容

- `Direct Distribution` と `App Store Connect` の違いが最初は曖昧だった
- notarized build ができたことで、そのまま App Store にも近い感覚があった
- 実際には全然別の提出ルートだった

#### 実際の整理

- `Developer ID` は App Store 外配布用
- `App Store Connect` は Mac App Store 提出用
- notarized だからといって App Store 要件を満たすわけではない
- App Store は Sandbox、metadata、privacy、review 対応が別途必要

#### 次回の教訓

- 早い段階で「今回の配布先」を固定する
- 直配布と App Store は別プロジェクトぐらいのつもりで進める

---

### 4. App Sandbox は「ON にしただけ」では通らなかった

#### 詰まった内容

- Xcode の `App Sandbox` を ON にして build / run が通っても、App Store Connect では
  `com.apple.security.app-sandbox` が無いと言われた
- つまり GUI 上の設定と、実際に埋め込まれる entitlement の関係が見えにくかった

#### 実際の原因

- `ENABLE_APP_SANDBOX = YES` は入っていた
- しかし `CODE_SIGN_ENTITLEMENTS` で参照する entitlements ファイルが無かった
- そのため、提出物の実行ファイルに sandbox entitlement が焼き込まれていなかった

#### 次回の教訓

- Sandbox を使うなら最初から `.entitlements` ファイルを作る
- Xcode の UI 表示だけで安心しない
- App Store 提出前に `codesign -d --entitlements :- <app>` で中身を見る

---

### 5. archive / export した app のどれが「最新の正解」か分かりにくかった

#### 詰まった内容

- `配布用.app`
- `配布用 2.app`
- archive 内の `.app`
- derived data の `.app`
- notarize 用 zip の中身

このあたりが複数できて、どれを信じればよいか分かりにくくなった

#### 実際の問題

- 途中で複数の build 成果物が散らばると、古い app を検証してしまう
- 署名や entitlement の壊れた `.app` が残ると判断がぶれる

#### 次回の教訓

- 「提出対象」または「配布対象」の app を1つに決める
- 命名ルールを固定する
  - 例: `StickyNative_release_candidate.app`
- 古い検証用 `.app` は早めに消す

---

### 6. App Store Connect の入力項目が多く、何が必須か分かりにくかった

#### 詰まった内容

- 著作権
- サポート URL
- プライバシーポリシー URL
- 暗号化
- 年齢制限
- カテゴリ
- コンテンツ配信権

このあたりが全部初見だとノイズが多い

#### 実際の整理

- まず必須なのは以下
  - 名前
  - サブタイトル
  - 説明文
  - キーワード
  - カテゴリ
  - スクリーンショット
  - サポート URL
  - プライバシーポリシー URL
  - App Privacy
  - 年齢制限
- それ以外はアプリの性質次第

#### 次回の教訓

- App Store Connect 用の下書き文面を先に作る
- サポートページと privacy ページを先に用意しておく
- 初回は「全部理解してから進む」より「一つずつ埋める」でよい

---

### 7. スクリーンショット制作の方針が曖昧だった

#### 詰まった内容

- macOS は iOS のような Simulator 撮影ではない
- 実機キャプチャだけでよいのか、Figma で加工すべきか迷いがあった
- メモ内容も空だと味気なく、何を書くべきか悩みやすかった

#### 実際の整理

- 実機スクショをベースにするのが自然
- Figma で余白・背景・見出しを整える程度がちょうどよい
- UI を AI で描き直す必要はない

#### 次回の教訓

- 最初にスクショ構成を決める
  - メニューバー
  - メモ入力
  - 一覧管理
  - セッション
  - ショートカット
- ダミーメモ文面も事前に用意する

---

### 8. 英語対応の仕様理解が曖昧だった

#### 詰まった内容

- 「海外からダウンロードされたら英語にしたい」という感覚だった
- 実際には、切り替え条件はダウンロード地域ではなく macOS の優先言語だった

#### 実際の整理

- App Store の表示言語とアプリ UI の言語は別
- アプリ本体は `Localizable.strings` などで実装が必要
- App Store Connect 側も英語ローカライズを別途入力する必要がある

#### 次回の教訓

- 早めに「日本語のみで出すか」「英語も同時にやるか」を決める
- UI 文字列直書きは後で必ず負債になる

---

## 特に詰まりやすかった心理ポイント

### 1. 同じ名前のものが多すぎる

- app
- archive
- export
- zip
- release
- upload

このあたりは概念が似ていて混ざりやすい

### 2. 「動いた」と「提出できる」が違う

- ローカル起動成功
- GitHub 配布可能
- notarization 通過
- App Store 提出可能
- App Review 通過

これは全部別のチェックポイント

### 3. Xcode の画面上で ON でも、成果物に入っていないことがある

- App Sandbox
- Signing
- Entitlements

このあたりは UI だけでなく成果物確認が必要

---

## 次回のための最短チェックリスト

### 配布前

- [ ] 提出先を最初に決める
  - [ ] GitHub / 直配布
  - [ ] App Store
- [ ] 署名方式を固定する
- [ ] アイコンを先に用意する
- [ ] サポート URL と privacy URL を早めに作る

### notarization 前

- [ ] `codesign -dv --verbose=4 <app>`
- [ ] `codesign --verify --deep --strict --verbose=4 <app>`
- [ ] 最終 app を fresh zip にする
- [ ] notarization 対象と配布対象が一致している

### App Store 提出前

- [ ] `.entitlements` がある
- [ ] `codesign -d --entitlements :- <app>` で確認
- [ ] サポート URL / privacy URL を入力
- [ ] 年齢制限 / 暗号化 / App Privacy を埋める
- [ ] スクショを先に用意する

---

## StickyNative で今回得た知見

- メニューバーアプリは見た目以上に配布周りが重い
- App Store 審査まで行くと、実装以外の作業量がかなりある
- ただし一周やると、次回は大幅に速くなる
- 次に同じ系統の macOS アプリを出すときは、今回の詰まりをかなり回避できる

---

## 次回へのメモ

- App Store 審査結果が返ってきたら、その内容もここに追記する
- 公開後にユーザーがつまずいた点も同じファイルに蓄積するとよい
