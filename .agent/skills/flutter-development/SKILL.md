---
name: flutter-development
description: Flutterモバイルアプリ製造スキル。Riverpod 3.0による状態管理、Widget実装パターン、パフォーマンス最適化、依存性注入を支援。機能実装、コーディング作業時に使用。
---

# Flutterモバイルアプリ製造スキル

## Riverpod 3.0 実装パターン

### Provider定義（コード生成）
```dart
// pubspec.yaml
dependencies:
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0

dev_dependencies:
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.0
```

```dart
// user_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_provider.g.dart';

@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  FutureOr<User?> build() async {
    return ref.watch(authRepositoryProvider).getCurrentUser();
  }

  Future<void> updateProfile(String name) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final updated = await ref.read(userRepositoryProvider).updateName(name);
      return updated;
    });
  }
}

// 生成実行: dart run build_runner build
```

### 依存性注入
```dart
// Repository Provider
@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthRepositoryImpl(dio: dio, storage: storage);
}

// Use Case Provider
@riverpod
Future<User> loginUseCase(LoginUseCaseRef ref, LoginParams params) async {
  final repository = ref.watch(authRepositoryProvider);
  return repository.login(params.email, params.password);
}
```

### State管理パターン
```dart
// AsyncValue ハンドリング
ref.watch(userProvider).when(
  data: (user) => UserProfile(user: user),
  loading: () => const LoadingIndicator(),
  error: (error, stack) => ErrorDisplay(error: error),
);

// Selector（部分監視）
final userName = ref.watch(
  userProvider.select((state) => state.valueOrNull?.name),
);
```

## Widget実装パターン

### StatelessWidget優先
```dart
// ✅ 推奨: Riverpod + StatelessWidget
class UserScreen extends ConsumerWidget {
  const UserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider);
    return userAsync.when(...);
  }
}

// 必要な場合のみ StatefulWidget + ConsumerStatefulWidget
class FormScreen extends ConsumerStatefulWidget {
  const FormScreen({super.key});

  @override
  ConsumerState<FormScreen> createState() => _FormScreenState();
}
```

### constコンストラクタ活用
```dart
// ✅ 再ビルド最小化
class MyWidget extends StatelessWidget {
  const MyWidget({super.key}); // const コンストラクタ

  @override
  Widget build(BuildContext context) {
    return const Column( // const で子ウィジェットをキャッシュ
      children: [
        Text('Static text'),
        Icon(Icons.star),
      ],
    );
  }
}
```

### Widget分割
```dart
// ❌ 巨大なbuild メソッド
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(...),
    body: Column(
      children: [
        // 100行以上のネスト...
      ],
    ),
  );
}

// ✅ 分割されたWidget
Widget build(BuildContext context) {
  return Scaffold(
    appBar: const _AppBar(),
    body: const _Body(),
  );
}

class _AppBar extends StatelessWidget {
  const _AppBar();
  // ...
}
```

## パフォーマンス最適化

### ListView最適化
```dart
// ✅ 遅延構築
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemTile(item: items[index]),
)

// ✅ 固定サイズでスクロール最適化
ListView.builder(
  itemExtent: 72.0, // 固定高さ
  itemBuilder: ...,
)

// ✅ 大量データはSliverで
CustomScrollView(
  slivers: [
    SliverAppBar(...),
    SliverList.builder(
      itemBuilder: ...,
    ),
  ],
)
```

### 画像最適化
```dart
// キャッシュ付き画像読み込み
CachedNetworkImage(
  imageUrl: url,
  placeholder: (context, url) => const Shimmer(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
  fadeInDuration: const Duration(milliseconds: 300),
)

// 適切なサイズ指定
Image.network(
  url,
  width: 100,
  height: 100,
  fit: BoxFit.cover,
  cacheWidth: 200, // デバイスピクセル比考慮
)
```

### 重い処理のIsolate化
```dart
// 重い処理をIsolateで実行
final result = await Isolate.run(() {
  // JSONパース、画像処理など
  return heavyComputation(data);
});

// compute関数（簡易版）
final parsed = await compute(parseJson, jsonString);
```

## ネットワーク通信

### Dio設定
```dart
@riverpod
Dio dio(DioRef ref) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://api.example.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  dio.interceptors.addAll([
    AuthInterceptor(ref),
    LogInterceptor(requestBody: true, responseBody: true),
    RetryInterceptor(dio: dio, retries: 3),
  ]);

  return dio;
}

// Auth Interceptor
class AuthInterceptor extends Interceptor {
  final Ref ref;
  AuthInterceptor(this.ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = ref.read(authTokenProvider);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
```

## ローカルストレージ

### Secure Storage
```dart
@riverpod
FlutterSecureStorage secureStorage(SecureStorageRef ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
}

// トークン保存
Future<void> saveToken(String token) async {
  await ref.read(secureStorageProvider).write(key: 'auth_token', value: token);
}
```

### SharedPreferences（非機密データ）
```dart
@riverpod
Future<SharedPreferences> sharedPrefs(SharedPrefsRef ref) async {
  return SharedPreferences.getInstance();
}

// 設定保存
Future<void> saveThemeMode(ThemeMode mode) async {
  final prefs = await ref.read(sharedPrefsProvider.future);
  await prefs.setString('theme_mode', mode.name);
}
```

## エラーハンドリング

### Result型パターン
```dart
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final AppException exception;
  const Failure(this.exception);
}

// 使用例
Future<Result<User>> getUser(String id) async {
  try {
    final response = await dio.get('/users/$id');
    return Success(User.fromJson(response.data));
  } on DioException catch (e) {
    return Failure(NetworkException.fromDioError(e));
  }
}
```

## チェックリスト

実装完了前に確認:
- [ ] Provider定義にコード生成を使用している
- [ ] constコンストラクタを可能な限り使用している
- [ ] ListView.builderで遅延構築している
- [ ] 画像にキャッシュを使用している
- [ ] 重い処理をIsolateで実行している
- [ ] エラーハンドリングが実装されている
- [ ] ローディング状態を表示している
- [ ] Secure Storageで機密データを保存している
