import 'package:flutter/material.dart';

import '../../core/services/scheduled_tasks_service.dart';
import '../../features/scheduled_tasks/pages/scheduled_tasks_page.dart';

/// Keep the task editor inside the settings pane, with its own back stack.
class DesktopScheduledTasksPane extends StatelessWidget {
  const DesktopScheduledTasksPane({super.key, this.service, this.navigatorKey});

  final ScheduledTasksService? service;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      builder: (_) => ScheduledTasksPage(service: service, embedded: true),
    ),
  );
}
