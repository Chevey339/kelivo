import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'ui_runtime_registry.dart';

/// The selector observes repository replacement/initialization, not every
/// streaming notification. Galleries without ChatService stay memory-only.
class UiPersistenceHost extends StatelessWidget {
  const UiPersistenceHost({
    super.key,
    required this.registry,
    required this.conversationId,
    required this.child,
  });
  final UiRuntimeRegistry registry;
  final String? conversationId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final repository = context.select<ChatService?, ChatDatabaseRepository?>(
      (service) => service?.chatRepositoryOrNull,
    );
    final service = context.read<ChatService?>();
    return _PersistenceLifecycle(
      registry: registry,
      repository: repository,
      service: service,
      conversationId: conversationId,
      child: child,
    );
  }
}

class _PersistenceLifecycle extends StatefulWidget {
  const _PersistenceLifecycle({
    required this.registry,
    required this.repository,
    required this.service,
    required this.conversationId,
    required this.child,
  });
  final UiRuntimeRegistry registry;
  final ChatDatabaseRepository? repository;
  final ChatService? service;
  final String? conversationId;
  final Widget child;
  @override
  State<_PersistenceLifecycle> createState() => _PersistenceLifecycleState();
}

class _PersistenceLifecycleState extends State<_PersistenceLifecycle>
    with WidgetsBindingObserver {
  ChatService? _registeredService;
  UiRuntimeRegistry? _registeredRegistry;
  void Function()? _removeSnapshotReader;

  void _configure() {
    widget.registry.configurePersistence(
      widget.repository?.genUiStates,
      canPersist: (id) =>
          widget.service != null &&
          !widget.service!.isTemporaryConversation(id),
    );
    if (!identical(_registeredService, widget.service) ||
        !identical(_registeredRegistry, widget.registry)) {
      _removeSnapshotReader?.call();
      _registeredService = widget.service;
      _registeredRegistry = widget.registry;
      _removeSnapshotReader = widget.service?.registerGenUiSnapshotReader(
        widget.registry.captureCopySnapshots,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configure();
  }

  @override
  void didUpdateWidget(_PersistenceLifecycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      widget.registry.leaveConversation(oldWidget.conversationId);
    }
    _configure();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) widget.registry.flush();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeSnapshotReader?.call();
    widget.registry.flush();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UiRuntimeScope(
    registry: widget.registry,
    revision: widget.registry.revision,
    child: widget.child,
  );
}
