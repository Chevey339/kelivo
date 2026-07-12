import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Widget/unit runners do not register native secure-storage plugins. A
  // process-wide in-memory platform keeps credential I/O deterministic and
  // prevents MethodChannel calls from waiting for a host that does not exist.
  FlutterSecureStorage.setMockInitialValues({});
  await testMain();
}
