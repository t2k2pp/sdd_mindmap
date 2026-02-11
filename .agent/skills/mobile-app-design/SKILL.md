---
name: mobile-app-design
description: モバイルアプリ設計スキル。要件定義から技術設計への変換、Clean Architectureの適用、状態管理パターン選択、データモデリングを支援。新規アプリ設計、既存アプリのリアーキテクチャ、設計レビュー時に使用。
---

# モバイルアプリ設計スキル

## 設計プロセス

### 1. 要件分析
```
入力: ユーザー要求、ビジネス要件
出力: 機能要件一覧、非機能要件一覧
```

1. ユーザーストーリーを整理
2. 機能要件を優先度付けでリスト化
3. 非機能要件を定義（パフォーマンス、セキュリティ、スケーラビリティ）

### 2. アーキテクチャ選定

#### Clean Architecture（推奨）
```
┌─────────────────────────────────────┐
│  Presentation Layer (UI/Widgets)    │
│  - Screens, Widgets, Controllers    │
├─────────────────────────────────────┤
│  Application Layer (Use Cases)      │
│  - Business Logic, State Management │
├─────────────────────────────────────┤
│  Domain Layer (Entities)            │
│  - Models, Interfaces               │
├─────────────────────────────────────┤
│  Data Layer (Repositories)          │
│  - API, Database, Local Storage     │
└─────────────────────────────────────┘
```

#### プロジェクト構造（Feature-First）
```
lib/
├── core/
│   ├── constants/
│   ├── errors/
│   ├── network/
│   └── utils/
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   └── presentation/
│   │       ├── providers/
│   │       ├── screens/
│   │       └── widgets/
│   └── [other_features]/
└── main.dart
```

### 3. 状態管理設計（Riverpod 3.0）

#### Provider種類選択
| ユースケース | Provider種類 |
|-------------|-------------|
| 定数値 | `Provider` |
| 変更可能な値 | `StateProvider` |
| 非同期データ取得 | `FutureProvider` |
| リアルタイム更新 | `StreamProvider` |
| 複雑なロジック | `NotifierProvider` |
| 非同期+複雑 | `AsyncNotifierProvider` |

#### 基本パターン
```dart
// Feature Provider
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  FutureOr<AuthState> build() async {
    return AuthState.initial();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final user = await ref.read(authRepositoryProvider).login(email, password);
      return AuthState.authenticated(user);
    });
  }
}
```

### 4. データモデリング

#### Entity定義
```dart
@freezed
class User with _$User {
  const factory User({
    required String id,
    required String email,
    required String name,
    @Default(false) bool isVerified,
    DateTime? createdAt,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

#### Repository Interface
```dart
abstract class AuthRepository {
  Future<User> login(String email, String password);
  Future<void> logout();
  Future<User?> getCurrentUser();
  Stream<User?> watchAuthState();
}
```

### 5. API設計

#### RESTful エンドポイント設計
```
GET    /api/v1/users          # List users
POST   /api/v1/users          # Create user
GET    /api/v1/users/:id      # Get user
PUT    /api/v1/users/:id      # Update user
DELETE /api/v1/users/:id      # Delete user
```

#### エラーハンドリング
```dart
sealed class AppException implements Exception {
  String get message;
}

class NetworkException extends AppException {
  @override
  final String message;
  final int? statusCode;
  NetworkException(this.message, {this.statusCode});
}

class ValidationException extends AppException {
  @override
  final String message;
  final Map<String, String>? fieldErrors;
  ValidationException(this.message, {this.fieldErrors});
}
```

## 設計成果物

### ADR（Architecture Decision Record）
```markdown
# ADR-XXX: [決定タイトル]

## ステータス
Proposed / Accepted / Deprecated / Superseded

## コンテキスト
[なぜこの決定が必要か]

## 決定
[何を決定したか]

## 結果
### メリット
- [利点1]

### デメリット
- [欠点1]

### 検討した代替案
- [代替案1]: [却下理由]
```

### 機能設計書テンプレート
詳細は `references/feature-design-template.md` を参照

## チェックリスト

設計完了前に確認:
- [ ] 全ユーザーストーリーが機能にマッピングされている
- [ ] 非機能要件（パフォーマンス目標、セキュリティ要件）が定義されている
- [ ] データモデルが正規化されている
- [ ] APIコントラクトが定義されている
- [ ] エラーハンドリング戦略が決まっている
- [ ] 状態管理パターンが選択されている
- [ ] テスト戦略が計画されている
