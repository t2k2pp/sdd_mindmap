# SDD MindMap (Flutter)

`app_specification.md` のMVP要件に沿って作成した、マインドマップ統合型タスク管理アプリです。

## 対応プラットフォーム
- iOS / iPadOS
- Android

## 主な機能 (MVP)
- マップ/ノード/タスクの作成・編集・削除
- ノードとタスクの紐付け
- マップビュー（ピンチズーム/パン、ノード移動）
- 全画面詳細ビュー（ノード/タスク）
- JSON/CSV(ZIP)/完全ZIP のエクスポート
- JSON/ZIP のインポート（統合/上書き/新規マップ）
- 共有受け取り（Share）

## 開発環境
```bash
flutter --version
flutter doctor -v
```

## 起動
```bash
flutter pub get
flutter run
```

## 共有受け取り (Share)

### Android
このリポジトリでは `AndroidManifest.xml` に `SEND` / `SEND_MULTIPLE` の intent-filter を設定済みです。
共有メニューで本アプリを選ぶと、URL/テキスト/ファイル情報をノードとして取り込みます。

### iOS / iPadOS
Flutter側の受信処理と `Runner/Info.plist` への基本設定は反映済みです。
ただし、iOSの共有機能は **XcodeでShare Extensionターゲット作成** が必要です。

1. Xcodeで `ios/Runner.xcworkspace` を開く
2. `File > New > Target > Share Extension` を作成（例: `Share Extension`）
3. `Runner` と `Share Extension` の両方に App Groups を追加し、同じ group を設定
   - 例: `group.com.t2k2pp.sdd_mindmap.share`
4. `ShareViewController.swift` を `RSIShareViewController` 継承に変更
   - `import receive_sharing_intent`
   - `class ShareViewController: RSIShareViewController {}`
5. `Build Phases` で `Embed Foundation Extension` を `Thin Binary` より上へ移動

この手順完了後、iOS/iPadOS でも共有メニューから本アプリへ取り込みできます。

## 品質チェック
```bash
flutter analyze
flutter test
```
