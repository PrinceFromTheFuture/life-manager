import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// An API key this app can hold on the user's behalf.
enum ApiKeyKind {
  googleVision(
    storageKey: 'google_vision_api_key',
    label: 'Google Cloud Vision',
    purpose: 'Reads the text off a photographed receipt.',
    where: 'console.cloud.google.com → APIs & Services → Credentials',
  ),
  openRouter(
    storageKey: 'openrouter_api_key',
    label: 'OpenRouter',
    purpose: 'Turns that text into the amount, shop and date.',
    where: 'openrouter.ai/keys',
  );

  const ApiKeyKind({
    required this.storageKey,
    required this.label,
    required this.purpose,
    required this.where,
  });

  final String storageKey;
  final String label;

  /// Written from the user's side of the screen: what it does for them, not
  /// which service it is.
  final String purpose;

  /// Where to go and get one.
  final String where;
}

/// Holds API keys in the platform keystore.
///
/// Keys are never in the repository, never in source, and never compiled into
/// the APK — anything baked into a build can be extracted from it by anyone
/// holding the file. Here they are entered once on the device, encrypted by the
/// Android Keystore, and can be replaced without a rebuild.
class ApiKeyStore {
  const ApiKeyStore(this._storage);

  final FlutterSecureStorage _storage;

  // v11's default constructor is already AES-GCM with RSA-OAEP key
  // wrapping — there's no flag to opt into; this exists only as the single
  // place every call site points at, in case that ever needs to change.
  static const AndroidOptions _androidOptions = AndroidOptions.defaultOptions;

  Future<String?> read(ApiKeyKind kind) =>
      _storage.read(key: kind.storageKey, aOptions: _androidOptions);

  Future<void> write(ApiKeyKind kind, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await clear(kind);
      return;
    }
    await _storage.write(
      key: kind.storageKey,
      value: trimmed,
      aOptions: _androidOptions,
    );
  }

  Future<void> clear(ApiKeyKind kind) =>
      _storage.delete(key: kind.storageKey, aOptions: _androidOptions);

  /// Which keys are present, without returning any of them.
  ///
  /// The UI only ever needs to know whether a key is set — reading the value
  /// into a widget just to render dots would put it somewhere it need not be.
  Future<Map<ApiKeyKind, bool>> presence() async {
    final result = <ApiKeyKind, bool>{};
    for (final kind in ApiKeyKind.values) {
      final value = await read(kind);
      result[kind] = value != null && value.isNotEmpty;
    }
    return result;
  }
}

final apiKeyStoreProvider = Provider<ApiKeyStore>(
  (ref) => const ApiKeyStore(FlutterSecureStorage()),
);

final apiKeyPresenceProvider = FutureProvider<Map<ApiKeyKind, bool>>(
  (ref) => ref.watch(apiKeyStoreProvider).presence(),
);

/// Whether receipt scanning can run at all. Both halves of the pipeline are
/// required: Vision reads the text, OpenRouter structures it.
final scanningAvailableProvider = Provider<bool>((ref) {
  final presence = ref.watch(apiKeyPresenceProvider).valueOrNull;
  if (presence == null) return false;
  return presence[ApiKeyKind.googleVision] == true &&
      presence[ApiKeyKind.openRouter] == true;
});
