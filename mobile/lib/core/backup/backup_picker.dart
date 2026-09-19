import 'package:flutter/services.dart';

/// Picks a backup zip through the system document picker.
///
/// Kept on a MethodChannel rather than a plugin so it does not fight
/// `share_plus` over Windows `win32` versions — this app is Android-first.
class BackupPicker {
  const BackupPicker();

  static const _channel = MethodChannel('spindle/android');

  /// Path to a cache copy of the chosen zip, or null if the user cancelled.
  Future<String?> pickZip() => _channel.invokeMethod<String>('pickBackupZip');
}
