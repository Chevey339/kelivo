import 'package:drift/drift.dart';

/// Delays or fails one real database commit without replacing its SQL work.
class CommitGate extends QueryInterceptor {
  Future<void> Function()? onNextCommit;
  bool afterCommit = false;

  @override
  Future<void> commitTransaction(TransactionExecutor inner) async {
    final callback = onNextCommit;
    onNextCommit = null;
    if (afterCommit) await inner.send();
    if (callback != null) await callback();
    if (!afterCommit) await inner.send();
  }
}
