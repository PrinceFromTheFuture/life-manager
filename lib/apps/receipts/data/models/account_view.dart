/// A named group of accounts — what the Accounts page is currently adding up.
///
/// Cash plus the checking account is "to spend". Those plus a locked savings
/// pot is "net worth". They are different numbers, so they are different
/// views rather than one total that pretends every pot is equally reachable.
///
/// [id] is null only for a draft that has not been saved. The built-in All
/// group is not a row: it is the absence of an active view.
class AccountView {
  const AccountView({
    this.id,
    required this.name,
    this.accountIds = const [],
    this.sort = 0,
  });

  final int? id;
  final String name;
  final List<int> accountIds;
  final int sort;

  static const String allLabel = 'All';

  bool contains(int accountId) => accountIds.contains(accountId);

  AccountView copyWith({
    int? id,
    String? name,
    List<int>? accountIds,
    int? sort,
  }) =>
      AccountView(
        id: id ?? this.id,
        name: name ?? this.name,
        accountIds: accountIds ?? this.accountIds,
        sort: sort ?? this.sort,
      );
}

AccountView? viewById(List<AccountView> views, int? id) {
  if (id == null) return null;
  for (final view in views) {
    if (view.id == id) return view;
  }
  return null;
}
