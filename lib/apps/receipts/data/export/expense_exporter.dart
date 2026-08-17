import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:shopping_list/apps/receipts/data/expense_repository.dart';
import 'package:shopping_list/apps/receipts/data/models/expense.dart';

/// Which slips a month export includes.
enum ExportScope {
  both,
  business,
  personal;

  String get label => switch (this) {
        ExportScope.both => 'Business and personal',
        ExportScope.business => 'Business only',
        ExportScope.personal => 'Personal only',
      };

  String get jsonName => name;

  bool includes(Expense expense) => switch (this) {
        ExportScope.both => true,
        ExportScope.business => expense.isBusiness,
        ExportScope.personal => !expense.isBusiness,
      };
}

/// A month's expenses, ready to hand to another app.
class ExpenseExport {
  const ExpenseExport({
    required this.fileName,
    required this.json,
    required this.count,
  });

  final String fileName;
  final String json;
  final int count;
}

/// Builds a month's expenses as JSON and offers it through the system share
/// sheet — Drive, WhatsApp, Files, a mail draft, whatever is on the phone.
///
/// The file is written to cache only so the share picker has something to
/// point at. It is not a saved copy in documents; that path was unreadable
/// from a file manager and made "export" feel like it had gone nowhere.
class ExpenseExporter {
  const ExpenseExporter(this._repo);

  final ExpenseRepository _repo;

  Future<ExpenseExport> buildMonth(
    DateTime month, {
    ExportScope scope = ExportScope.both,
  }) async {
    final start = DateTime(month.year, month.month);
    final nextMonth = DateTime(month.year, month.month + 1);
    final expenses =
        (await _repo.between(start, nextMonth)).where(scope.includes).toList();
    final categoryNames = {
      for (final c in await _repo.categories()) c.id: c.name,
    };
    final accountNames = {for (final a in await _repo.accounts()) a.id: a.name};

    final rows = [
      for (final expense in expenses)
        _row(expense, categoryNames, accountNames),
    ];

    final stamp = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final suffix = switch (scope) {
      ExportScope.both => '',
      ExportScope.business => '_business',
      ExportScope.personal => '_personal',
    };
    final fileName = 'receipts_$stamp$suffix.json';

    return ExpenseExport(
      fileName: fileName,
      json: const JsonEncoder.withIndent('  ').convert({
        'month': stamp,
        'scope': scope.jsonName,
        'exportedAt': DateTime.now().toIso8601String(),
        'count': rows.length,
        'expenses': rows,
      }),
      count: rows.length,
    );
  }

  /// Writes [export] to cache and opens the system share sheet.
  Future<void> share(ExpenseExport export) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, export.fileName));
    await file.writeAsString(export.json);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        fileNameOverrides: [export.fileName],
        title: export.fileName,
        subject: export.fileName,
      ),
    );
  }

  Future<void> shareMonth(
    DateTime month, {
    ExportScope scope = ExportScope.both,
  }) async {
    await share(await buildMonth(month, scope: scope));
  }

  Map<String, Object?> _row(
    Expense expense,
    Map<int?, String> categoryNames,
    Map<int?, String> accountNames,
  ) {
    return {
      'id': expense.id,
      'date': expense.occurredAt.toIso8601String(),
      'amount': expense.amountMinor / 100,
      'currency': expense.currency,
      'merchant': expense.merchant,
      'description': expense.description,
      'category': categoryNames[expense.categoryId],
      'account': accountNames[expense.accountId],
      'location': expense.locationLabel,
      'latitude': expense.latitude,
      'longitude': expense.longitude,
      'source': expense.source.name,
      'business': expense.isBusiness,
    };
  }
}
