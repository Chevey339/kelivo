import 'package:flutter/widgets.dart';

import '../../../core/services/search/search_service.dart';

void clearFourGetPassOnOriginChange({
  required TextEditingController urlController,
  required TextEditingController passController,
}) {
  String? readOrigin() =>
      FourGetOptions.parseInstanceUrl(urlController.text)?.origin;

  var lastOrigin = readOrigin();
  if (lastOrigin == null && passController.text.isNotEmpty) {
    passController.clear();
  }
  urlController.addListener(() {
    final origin = readOrigin();
    // Keep the last valid origin while the address is being edited.
    if (origin == null || origin == lastOrigin) return;
    if (lastOrigin != null) passController.clear();
    lastOrigin = origin;
  });
}
