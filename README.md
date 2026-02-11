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
Share Extension ターゲットは作成済みです。  
Xcode側の作業は署名関連の最小設定のみです。

1. Xcodeで `ios/Runner.xcworkspace` を開く
2. `Runner` と `Share Extension` の `Signing & Capabilities` で同じ Team を設定
3. 両ターゲットに App Groups を追加し、同じ値を設定  
   - `group.com.t2k2pp.sddmindmap.share`
4. 必要なら `PRODUCT_BUNDLE_IDENTIFIER` をあなたの組織IDに合わせて調整  
   - `Runner`  
   - `Share Extension` (`Runner` のプレフィックス + `.ShareExtension`)

ここまでで、iOS/iPadOS でも共有メニューから本アプリへ取り込みできます。

## 品質チェック
```bash
flutter analyze
flutter test
```
