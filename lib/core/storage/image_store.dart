import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Owns receipt images on disk.
///
/// Two rules hold this together, and breaking either one loses people's
/// receipts:
///
/// 1. **Images live in the app documents directory, not where the picker left
///    them.** `image_picker` returns a file in a cache directory the OS is free
///    to purge at any time. The file is copied out before its path is stored.
///
/// 2. **Only the relative path is persisted.** The absolute container path
///    changes between installs and OS upgrades, so an absolute path recorded
///    today silently fails to resolve later. Absolute paths are reconstructed
///    at read time by [resolve].
class ImageStore {
  ImageStore({Directory? root}) : _rootOverride = root;

  final Directory? _rootOverride;
  Directory? _cached;

  static const String _subdir = 'receipts';

  Future<Directory> _root() async {
    final override = _rootOverride;
    if (override != null) return override;
    return _cached ??= await getApplicationDocumentsDirectory();
  }

  /// Copies [sourcePath] into managed storage and returns the path to record
  /// in the database, relative to the documents directory.
  Future<String> saveReceipt(String sourcePath, {int? tripId}) async {
    final root = await _root();
    final dir = Directory(p.join(root.path, _subdir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final extension = p.extension(sourcePath).toLowerCase();
    final safeExtension = extension.isEmpty ? '.jpg' : extension;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'receipt_${tripId ?? 'draft'}_$stamp$safeExtension';

    final destination = p.join(dir.path, fileName);
    await File(sourcePath).copy(destination);

    // Forward slashes so the stored value is stable if the database is ever
    // moved between platforms.
    return '$_subdir/$fileName';
  }

  /// Turns a stored relative path back into a readable file.
  Future<File> resolve(String relativePath) async {
    final root = await _root();
    return File(p.join(root.path, relativePath));
  }

  /// Whether the image a trip points at is actually still on disk. History
  /// renders a stated placeholder when it isn't, rather than a broken frame.
  Future<bool> exists(String relativePath) async =>
      (await resolve(relativePath)).exists();

  Future<void> delete(String relativePath) async {
    final file = await resolve(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
