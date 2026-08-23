import 'package:flutter/material.dart';

import 'package:shopping_list/apps/receipts/data/models/category_ink.dart';

/// The printed mark of an account: one icon, one stamp-pad ink.
///
/// Closed set, same rule as [CategoryInk]. A passbook page is identified by
/// the well on its corner, not by a rainbow of free colours.
@immutable
class AccountMark {
  const AccountMark({
    required this.id,
    required this.label,
    required this.icon,
    required this.ink,
  });

  final String id;
  final String label;
  final IconData icon;
  final CategoryInk ink;

  static const String fallbackId = vaultId;
  static const String vaultId = 'vault';

  static const vault = AccountMark(
    id: vaultId,
    label: 'Vault',
    icon: Icons.account_balance_outlined,
    ink: CategoryInk.ledger,
  );

  static const wallet = AccountMark(
    id: 'wallet',
    label: 'Wallet',
    icon: Icons.account_balance_wallet_outlined,
    ink: CategoryInk.mustard,
  );

  static const plate = AccountMark(
    id: 'plate',
    label: 'Plate',
    icon: Icons.credit_card_outlined,
    ink: CategoryInk.carmine,
  );

  static const atm = AccountMark(
    id: 'atm',
    label: 'Till',
    icon: Icons.local_atm_outlined,
    ink: CategoryInk.teal,
  );

  static const leaf = AccountMark(
    id: 'leaf',
    label: 'Leaf',
    icon: Icons.savings_outlined,
    ink: CategoryInk.pine,
  );

  static const coins = AccountMark(
    id: 'coins',
    label: 'Coins',
    icon: Icons.toll_outlined,
    ink: CategoryInk.scorch,
  );

  static const safe = AccountMark(
    id: 'safe',
    label: 'Safe',
    icon: Icons.lock_outline,
    ink: CategoryInk.violet,
  );

  static const tin = AccountMark(
    id: 'tin',
    label: 'Tin',
    icon: Icons.inventory_2_outlined,
    ink: CategoryInk.iron,
  );

  static const List<AccountMark> all = [
    vault,
    wallet,
    plate,
    atm,
    leaf,
    coins,
    safe,
    tin,
  ];

  static AccountMark byId(String? id) {
    if (id == null || id.isEmpty) return vault;
    for (final mark in all) {
      if (mark.id == id) return mark;
    }
    return vault;
  }

  /// Kind-sensible default, then the least-used pad so two banks do not
  /// stamp identical.
  static String next(Iterable<String> usedIds, {String kind = 'other'}) {
    final preferred = switch (kind) {
      'cash' => wallet.id,
      'card' => plate.id,
      'bank' => vault.id,
      _ => coins.id,
    };
    final used = usedIds.map(byId).map((m) => m.id).toSet();
    if (!used.contains(preferred)) return preferred;

    final counts = {for (final mark in all) mark.id: 0};
    for (final id in usedIds) {
      final resolved = byId(id).id;
      counts[resolved] = (counts[resolved] ?? 0) + 1;
    }
    var best = all.first;
    var min = counts[best.id]!;
    for (final mark in all.skip(1)) {
      final n = counts[mark.id]!;
      if (n < min) {
        min = n;
        best = mark;
      }
    }
    return best.id;
  }

  @override
  bool operator ==(Object other) => other is AccountMark && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
