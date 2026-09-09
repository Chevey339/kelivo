import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/mirror_service.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_dialogs.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/task_progress_dialog.dart';
import 'package:Kelivo/theme/theme_factory.dart';

import '../../../support/business_test_harness.dart';
import 'environment_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EnvironmentProvider env;
  late _ControllableMirrorService mirrors;

  setUp(() async {
    env = EnvironmentProvider(preferences: createBusinessTestPreferences());
    await env.loaded;
    mirrors = _ControllableMirrorService(env);
  });

  Future<void> drainSnackbars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  Future<AppLocalizations> pumpHost(WidgetTester tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<EnvironmentProvider>.value(value: env),
        ],
        child: MaterialApp(
          theme: buildLightTheme(null),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () {
                      unawaited(
                        runDetectFastMirrors(
                          context: context,
                          mirrors: mirrors,
                          categories: {MirrorCategory.npm},
                        ),
                      );
                    },
                    child: const Text('start-detect'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    return l10n;
  }

  testWidgets('cancel closes the dialog and invokes cancellation', (
    tester,
  ) async {
    final l10n = await pumpHost(tester);
    await tester.tap(find.text('start-detect'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TaskProgressDialogCard), findsOneWidget);
    expect(mirrors.lastCancelToken, isNotNull);

    await tester.tap(find.byKey(const Key('task_progress_cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TaskProgressDialogCard), findsNothing);
    expect(mirrors.lastCancelToken!.isCancelled, isTrue);
    expect(find.text(l10n.workspaceEnvMirrorsTested), findsNothing);
    expect(find.text(l10n.workspaceEnvMirrorsFailed), findsNothing);
  });

  testWidgets('success auto-closes the dialog', (tester) async {
    mirrors.completeImmediately = true;
    await pumpHost(tester);
    await tester.tap(find.text('start-detect'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(TaskProgressDialogCard), findsNothing);
    await drainSnackbars(tester);
  });

  testWidgets('failure shows acknowledge which closes the dialog', (
    tester,
  ) async {
    mirrors.autoDetectError = StateError('guest hung');
    mirrors.completeImmediately = true;
    final l10n = await pumpHost(tester);
    await tester.tap(find.text('start-detect'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(TaskProgressDialogCard), findsOneWidget);
    expect(find.text(l10n.workspaceEnvMirrorsFailed), findsWidgets);

    await tester.tap(find.byKey(const Key('task_progress_acknowledge')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(TaskProgressDialogCard), findsNothing);
    await drainSnackbars(tester);
  });
}

class _ControllableMirrorService extends FakeMirrorService {
  _ControllableMirrorService(super.env);

  final Completer<void> _hold = Completer<void>();
  bool completeImmediately = false;
  MirrorCancelToken? lastCancelToken;

  @override
  Future<void> autoDetectAndApplyAll({
    required Set<MirrorCategory> categories,
    void Function(MirrorDetectProgress progress)? onProgress,
    bool skipManualPicks = true,
    MirrorCancelToken? cancelToken,
  }) async {
    lastCancelToken = cancelToken;
    autoDetectCalls += 1;
    if (!completeImmediately) {
      await Future.any<void>([
        _hold.future,
        if (cancelToken != null) cancelToken.whenCancelled,
      ]);
    }
    cancelToken?.throwIfCancelled();
    final error = autoDetectError;
    if (error != null) throw error;
    onProgress?.call(
      MirrorDetectProgress(
        fraction: 1,
        category: categories.first,
        phase: MirrorDetectPhase.applying,
      ),
    );
  }
}
