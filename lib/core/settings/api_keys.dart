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

/// Holds API keys on this phone.
///
/// They are entered once and stored by the platform, never compiled into the
/// APK. A full copy dumps them too — this app is local, and restore has to
/// bring scanning back with everything else.
class ApiKeyStore {
  const ApiKeyStore(this._storage);

  final FlutterSecureStorage _storage;

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

  /// Every key this phone is holding. Used by the full-app copy.
  Future<Map<String, String>> exportAll() async {
    final all = await _storage.readAll(aOptions: _androidOptions);
    return {
      for (final e in all.entries)
        if (e.value.trim().isNotEmpty) e.key: e.value.trim(),
    };
  }

  /// Replaces every key with [values]. Missing entries are cleared, so a
  /// restore matches the copy rather than merging with leftovers.
  Future<void> importAll(Map<String, String> values) async {
    await _storage.deleteAll(aOptions: _androidOptions);
    for (final e in values.entries) {
      final trimmed = e.value.trim();
      if (trimmed.isEmpty) continue;
      await _storage.write(
        key: e.key,
        value: trimmed,
        aOptions: _androidOptions,
      );
    }
  }

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
