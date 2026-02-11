---
name: flutter-environment-check
description: Flutter開発環境診断スキル。flutter doctor、SDK/NDK確認、プロジェクト設定検証を支援。プロジェクト開始時、ネイティブプラグイン導入時に使用。
---

# Flutter 開発環境診断スキル

プロジェクト初期化時およびネイティブプラグイン導入時に、開発環境の整合性を確認するスキル。

---

## 🔍 診断タイミング

| タイミング | 必須診断項目 |
|-----------|-------------|
| プロジェクト新規作成時 | flutter doctor, SDK確認 |
| ネイティブプラグイン導入時 | minSdk, NDK, Kotlin/Swift互換性 |
| ビルドエラー発生時 | 詳細環境診断 |
| Flutter/Dartアップグレード時 | 全体再診断 |

---

## 1. 基本診断コマンド

### flutter doctor
```bash
flutter doctor -v
```

**確認項目:**
- [ ] Flutter SDK バージョン（3.19+推奨）
- [ ] Dart SDK バージョン（3.3+推奨）
- [ ] Android toolchain（全てチェック通過）
- [ ] Xcode（iOSビルド時）
- [ ] Android Studio / VS Code

### SDK/NDKパス確認
```bash
# Androidの場合
echo $ANDROID_HOME
# または
echo $ANDROID_SDK_ROOT

# NDK確認
ls $ANDROID_HOME/ndk/
```

---

## 2. プロジェクト設定診断

### Android設定確認

#### android/app/build.gradle
```groovy
// 確認項目
android {
    compileSdk 34          // 最新推奨: 34-36
    
    defaultConfig {
        minSdk 21          // 多くのプラグインは21以上必要
        targetSdk 34       // 最新推奨: 34
    }
    
    // Kotlin/Java互換性
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = '17'
    }
}
```

#### android/build.gradle
```groovy
buildscript {
    ext.kotlin_version = '1.9.22'  // 2026年2月推奨
    
    dependencies {
        classpath 'com.android.tools.build:gradle:8.2.0'  // AGP最新
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}
```

#### android/gradle/wrapper/gradle-wrapper.properties
```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.4-all.zip
```

### iOS設定確認

#### ios/Podfile
```ruby
platform :ios, '13.0'  # 多くのプラグインは13.0以上必要

# CocoaPods推奨設定
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
```

#### ios/Runner.xcodeproj/project.pbxproj（確認項目）
- `IPHONEOS_DEPLOYMENT_TARGET` = 13.0以上
- `SWIFT_VERSION` = 5.0以上

#### CocoaPods診断
```bash
# バージョン確認
pod --version
# 推奨: 1.14.x以上

# キャッシュクリア・再インストール
cd ios
rm -rf Pods Podfile.lock
pod repo update
pod install --repo-update
```

### iOS固有の互換性マトリクス

| Xcode | Swift | iOS最低 | 備考 |
|-------|-------|---------|------|
| 15.0+ | 5.9+ | 12.0+ | Flutter 3.16+ |
| 15.2+ | 5.9.2+ | 13.0+ | Flutter 3.19推奨 |
| 16.0+ | 6.0+ | 13.0+ | 最新 |

### iOS環境診断コマンド

```bash
# Xcode確認
xcodebuild -version
xcrun --show-sdk-path

# Swift確認
swift --version

# CocoaPods確認
pod --version
pod env

# シミュレータ一覧
xcrun simctl list devices
```

---

## 3. ネイティブプラグイン導入前チェックリスト

### 導入前確認事項

```
□ pub.devでパッケージのREADME確認
□ Changelogで最新の変更を確認
□ GitHubのIssueで既知の問題を検索
□ 以下のネイティブ要件を確認:
```

| 確認項目 | 確認方法 |
|---------|---------|
| 最低minSdk | パッケージREADME / android/build.gradle |
| 必要NDKバージョン | パッケージREADME / ビルドエラー |
| Kotlin互換性 | GitHub Issue検索 |
| Swift/iOS最低バージョン | パッケージREADME / Podfile |

### 導入後確認事項

```bash
# 必須: ビルドテスト実行
flutter build apk --debug

# iOSの場合
cd ios && pod install && cd ..
flutter build ios --debug --no-codesign
```

---

## 4. よくある環境問題と解決策

### NDKバージョン不一致

**症状:**
```
NDK at ~/Android/Sdk/ndk/26.3.x did not have a source.properties file
Execution failed for task ':health:externalNativeBuildDebug'
```

**解決:**
```bash
# 必要なNDKをインストール
sdkmanager "ndk;27.0.12077973"

# local.propertiesで明示
echo "ndk.dir=$ANDROID_SDK_ROOT/ndk/27.0.12077973" >> android/local.properties
```

### minSdkVersion不足

**症状:**
```
uses-sdk:minSdkVersion 21 cannot be smaller than version 26 declared in library
```

**解決:**
```groovy
// android/app/build.gradle
defaultConfig {
    minSdk 26  // プラグイン要求に合わせて上げる
}
```

### Kotlin互換性エラー

**症状:**
```
Unresolved reference: Registrar
Cannot access class 'io.flutter.plugin.common.PluginRegistry$Registrar'
```

**原因:** 古いFlutter埋め込みAPI（v1）を使用するプラグイン

**解決:**
1. プラグインを最新バージョンにアップグレード
2. それでも解決しない場合はプラグインのIssueを確認
3. 代替プラグインを検討

### AGP（Android Gradle Plugin）バージョン不整合

**症状:**
```
The project uses incompatible version of the Android Gradle plugin.
```

**解決:**
```groovy
// android/build.gradle
dependencies {
    classpath 'com.android.tools.build:gradle:8.2.0'  // 最新に更新
}

// android/gradle/wrapper/gradle-wrapper.properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.4-all.zip
```

### CocoaPods エラー（iOS）

**症状:**
```
[!] CocoaPods could not find compatible versions
```

**解決:**
```bash
cd ios
rm -rf Pods Podfile.lock
pod repo update
pod install
```

---

## 5. 環境診断スクリプト

### 一括診断（PowerShell）
```powershell
Write-Host "=== Flutter Environment Check ===" -ForegroundColor Cyan

# Flutter/Dart
flutter --version
dart --version

# Android SDK
Write-Host "`n=== Android SDK ===" -ForegroundColor Cyan
if (Test-Path env:ANDROID_HOME) {
    Write-Host "ANDROID_HOME: $env:ANDROID_HOME"
    Get-ChildItem "$env:ANDROID_HOME/ndk" -ErrorAction SilentlyContinue
} else {
    Write-Host "ANDROID_HOME not set!" -ForegroundColor Red
}

# Project settings
Write-Host "`n=== Project Settings ===" -ForegroundColor Cyan
if (Test-Path "android/app/build.gradle") {
    Select-String -Path "android/app/build.gradle" -Pattern "minSdk|compileSdk|targetSdk"
}

# flutter doctor
Write-Host "`n=== Flutter Doctor ===" -ForegroundColor Cyan
flutter doctor
```

---

## 6. 推奨環境（2026年2月時点）

| 項目 | 推奨バージョン |
|------|---------------|
| Flutter | 3.19+ |
| Dart | 3.3+ |
| Android Studio | 2024.x+ |
| Xcode | 15.0+ |
| Android SDK | 34+ |
| Android NDK | 27.0.x |
| Kotlin | 1.9.22+ |
| Gradle | 8.4+ |
| AGP | 8.2.0+ |
| iOS Deployment Target | 13.0+ |

---

## チェックリスト

### 新規プロジェクト開始時
- [ ] flutter doctor -v で全項目パス
- [ ] Android SDK/NDKが最新
- [ ] プロジェクトのminSdk/compileSdk確認
- [ ] Kotlin/Gradleバージョン確認

### ネイティブプラグイン導入時
- [ ] パッケージのREADME/Changelog確認
- [ ] ネイティブ要件（minSdk, NDK, Kotlin）確認
- [ ] `flutter build apk --debug` でビルドテスト
- [ ] iOS: `pod install` → `flutter build ios --debug`
