import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'package:shopping_list/apps/receipts/data/models/expense.dart';
import 'package:shopping_list/core/util/money.dart';

/// One photo the desk should forward to the accountant.
class AccountantPayload {
  const AccountantPayload({
    required this.expenseId,
    required this.filePath,
    required this.filename,
    required this.caption,
  });

  final int expenseId;
  final String filePath;
  final String filename;
  final String caption;

  factory AccountantPayload.fromExpense(Expense expense, File file) {
    final when = expense.occurredAt.toLocal();
    final y = when.year.toString().padLeft(4, '0');
    final m = when.month.toString().padLeft(2, '0');
    final d = when.day.toString().padLeft(2, '0');
    return AccountantPayload(
      expenseId: expense.id!,
      filePath: file.path,
      filename: p.basename(file.path),
      caption: '${expense.title} · ${Money.format(expense.amountMinor)} · $d.$m.$y',
    );
  }
}

/// The WhatsApp desk that forwards business slips to the accountant.
class AccountantDesk {
  AccountantDesk(this.origin, {http.Client? client})
      : _client = client ?? http.Client();

  /// The live desk. Override on this phone only when pointing at a local box.
  static const hostedOrigin = 'https://life-manager.receipts.kantara.co.il';

  /// Where a one-phone override is kept, if any.
  static const storageKey = 'accountant_desk_url';

  final String origin;
  final http.Client _client;

  static String normalizeOrigin(String raw) {
    var value = raw.trim();
    if (value.endsWith('/')) value = value.substring(0, value.length - 1);
    if (!value.contains('://')) value = 'http://$value';
    return value;
  }

  Uri get _transmit => Uri.parse('$origin/transmit');

  /// Hands [payloads] to the desk. The desk sends them on, twenty seconds
  /// apart, so the accountant's phone can digest each photo.
  Future<int> transmit(List<AccountantPayload> payloads) async {
    if (payloads.isEmpty) return 0;
    final request = http.MultipartRequest('POST', _transmit);
    request.fields['captions'] = jsonEncode([
      for (final payload in payloads) payload.caption,
    ]);
    for (final payload in payloads) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'receipts',
          payload.filePath,
          filename: payload.filename,
        ),
      );
    }

    final streamed = await _client.send(request).timeout(
          const Duration(seconds: 45),
        );
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode == 202 || streamed.statusCode == 200) {
      return payloads.length;
    }
    if (streamed.statusCode == 503) {
      throw AccountantDeskException('WhatsApp is not connected at the desk.');
    }
    throw AccountantDeskException(
      _messageFrom(body) ?? 'Desk returned ${streamed.statusCode}.',
    );
  }

  static String? _messageFrom(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}

class AccountantDeskException implements Exception {
  AccountantDeskException(this.message);
  final String message;

  @override
  String toString() => message;
}
