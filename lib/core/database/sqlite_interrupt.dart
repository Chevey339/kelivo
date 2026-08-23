import 'dart:ffi';

import 'package:flutter/foundation.dart';

/// Calls `sqlite3_interrupt` on the same native library that opened the
/// connection. The published sqlite3 asset may omit this symbol; a lookup
/// failure is ignored and the existing isolate kill path still runs.
@Native<Void Function(Pointer<Void>)>(
  assetId: 'package:sqlite3/src/ffi/libsqlite3.g.dart',
  symbol: 'sqlite3_interrupt',
)
external void _sqlite3Interrupt(Pointer<Void> db);

@visibleForTesting
void Function(int handleAddress)? debugOnInterruptSqliteHandle;

void interruptSqliteHandle(int address) {
  final debugHook = debugOnInterruptSqliteHandle;
  if (debugHook != null) {
    debugHook(address);
    return;
  }
  if (address == 0) return;
  try {
    _sqlite3Interrupt(Pointer<Void>.fromAddress(address));
  } catch (_) {
    // Native asset may have stripped sqlite3_interrupt. Kill still follows.
  }
}
