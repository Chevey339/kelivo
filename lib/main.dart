import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:async';
import 'dart:ui' show AppExitResponse;
import 'l10n/app_localizations.dart';
import 'features/home/pages/home_page.dart';
import 'features/migration/hive_to_sqlite_migration_page.dart';
import 'features/migration/hive_to_sqlite_migration_service.dart';
import 'desktop/desktop_home_page.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'desktop/desktop_window_controller.dart';
import 'desktop/desktop_tray_controller.dart';
// import 'package:logging/logging.dart' as logging;
// Theme is now managed in SettingsProvider
import 'theme/theme_factory.dart';
import 'theme/palettes.dart';
import 'theme/custom_theme.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'core/providers/user_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/mcp_provider.dart';
import 'core/providers/tts_provider.dart';
import 'core/providers/asr_provider.dart';
import 'core/providers/assistant_provider.dart';
import 'core/providers/tag_provider.dart';
import 'core/providers/update_provider.dart';
import 'core/providers/quick_phrase_provider.dart';
import 'core/providers/instruction_injection_provider.dart';
import 'core/providers/instruction_injection_group_provider.dart';
import 'core/providers/world_book_provider.dart';
import 'core/providers/memory_provider.dart';
import 'core/providers/memory_provider_v2.dart';
import 'core/providers/backup_provider.dart';
import 'core/providers/local_snapshot_provider.dart';
import 'features/backup/local_snapshot_scheduler.dart';
import 'core/services/memory/memory_pipeline.dart';
import 'core/services/memory/memory_repository.dart';
import 'core/providers/s3_backup_provider.dart';
import 'core/providers/backup_reminder_provider.dart';
import 'core/providers/hotkey_provider.dart';
import 'core/database/database_installation_gate.dart';
import 'core/database/app_database.dart';
import 'core/database/business_migration_engine.dart';
import 'core/database/business_preferences.dart';
import 'core/database/business_repository.dart';
import 'core/database/business_startup_gate.dart';
import 'core/database/chat_database_gateway.dart';
import 'core/database/startup_failure_report.dart';
import 'core/services/backup/backup_activity.dart';
import 'core/services/backup/local_snapshot_schedule.dart';
import 'core/services/chat/chat_service.dart';
import 'core/services/app_exit_flush.dart';
import 'core/services/backup/restore_archive_pruner.dart';
import 'core/services/backup/restore_business_lease.dart';
import 'core/services/backup/restore_startup_gate.dart';
import 'core/services/backup/restore_receipt.dart';
import 'core/services/mcp/mcp_tool_service.dart';
import 'core/services/logging/flutter_logger.dart';
import 'core/services/storage/storage_usage_service.dart';
import 'features/home/services/ask_user_interaction_service.dart';
import 'features/home/services/tool_approval_service.dart';
import 'utils/app_directories.dart';
import 'utils/platform_utils.dart';
import 'utils/sandbox_path_resolver.dart';
import 'shared/widgets/app_overlays.dart';
import 'shared/widgets/snackbar.dart';
import 'shared/widgets/restore_failure_screen.dart';
import 'shared/widgets/restore_outcome_notice.dart';
import 'shared/widgets/update_required_screen.dart';
import 'package:system_fonts/system_fonts.dart';
import 'dart:io'
    show
        Directory,
        File,
        FileMode,
        Platform,
        stderr; // kept for global override usage inside provider
import 'core/services/android_background.dart';
import 'core/services/notification_service.dart';
import 'features/home/controllers/chat_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';

final RouteObserver<ModalRoute<dynamic>> routeObserver =
    RouteObserver<ModalRoute<dynamic>>();
bool _didCheckUpdates = false; // one-time update check flag
bool _didEnsureAssistants = false; // ensure defaults after l10n ready
Color?
_lastWindowBg; // last window native background, to avoid resize black flash

Future<void> main() async {
  await runZoned(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // Register notification tap handling for every Android launch. This is
      // independent of the current background-chat mode: an older completion
      // notification can still launch the app after the mode has changed.
      // Initialization does not request notification permission.
      if (Platform.isAndroid) {
        try {
          await NotificationService.ensureInitialized();
        } catch (_) {}
      }
      FlutterLogger.installGlobalHandlers();
      final appDataDirectory = await AppDirectories.getAppDataDirectory();
      final RestoreReceipt? restoreOutcome;
      try {
        // The lease remains process-owned through its internal registry until
        // process exit, preventing another instance from racing business I/O.
        final businessLease = await RestoreBusinessLease.acquire(
          appDataDirectory: appDataDirectory,
        );
        restoreOutcome =
            await RestoreStartupGate.recoverAndRequireBusinessReady(
              appDataDirectory: appDataDirectory,
              businessLease: businessLease,
            );
      } catch (error, stackTrace) {
        stderr.writeln('[RestoreStartupGate] $error\n$stackTrace');
        await _initRestoreFailureWindow();
        runApp(
          _RestoreFailureApp(
            report: StartupFailureReport.capture(
              stage: StartupFailureStage.restoreGate,
              error: error,
              step: 'recover_and_require_business_ready',
              stackTrace: stackTrace,
            ),
            appDataDirectory: appDataDirectory,
          ),
        );
        return;
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        final enabled = prefs.getBool('flutter_log_enabled_v1') ?? false;
        await FlutterLogger.setEnabled(enabled);
      } catch (_) {}
      // Trim Flutter global image cache to reduce memory pressure from large images
      try {
        PaintingBinding.instance.imageCache.maximumSize = 200;
        PaintingBinding.instance.imageCache.maximumSizeBytes =
            48 << 20; // ~48MB
      } catch (_) {}
      // Desktop (Windows) window setup: hide native title bar for custom Flutter bar
      await _initDesktopWindow();
      // Avoid preloading all system fonts at launch (huge memory on desktop)
      // Debug logging and global error handlers were enabled previously for diagnosis.
      // They are commented out now per request to reduce log noise.
      // FlutterError.onError = (FlutterErrorDetails details) { ... };
      // WidgetsBinding.instance.platformDispatcher.onError = (Object error, StackTrace stack) { ... };
      // logging.Logger.root.level = logging.Level.ALL;
      // logging.Logger.root.onRecord.listen((rec) { ... });
      // Cache current Documents directory to fix sandboxed absolute paths on iOS
      await SandboxPathResolver.init();
      ChatDatabaseLease? processDatabaseLease;
      BusinessPreferences? businessPreferences;
      var recoveryAttempted = false;
      // Every call below can fail through drift's worker isolate, which erases
      // the distinction between them. Naming the current one is what lets the
      // failure screen say where startup actually stopped.
      var admissionStep = 'legacy_migration_check';
      while (true) {
        try {
          admissionStep = 'legacy_migration_check';
          final migrationDecision = await HiveToSqliteMigrationService.check();
          if (migrationDecision.needsMigration) {
            runApp(
              MigrationApp(
                service: HiveToSqliteMigrationService(migrationDecision),
                restoreOutcome: restoreOutcome?.state,
              ),
            );
            return;
          }
          admissionStep = 'installation_gate';
          await DatabaseInstallationGate.ensureReady(
            appDataDirectory: appDataDirectory,
            allowDatabaseIdentityChange:
                restoreOutcome?.selectedComponents.contains(
                  RestoreComponent.database,
                ) ??
                false,
          );
          final databaseFile = File(
            '${appDataDirectory.path}/${AppDatabase.databaseFileName}',
          );
          admissionStep = 'gateway_open';
          final databaseLease = await ChatDatabaseGateway.instance.acquire(
            databaseFile,
          );
          try {
            admissionStep = 'business_migration';
            final legacyPreferences =
                await SharedPreferencesLegacyBusinessPreferences.open();
            final loadedBusinessPreferences =
                await BusinessStartupGate.migrateAndLoad(
                  repository: databaseLease.businessRepository,
                  legacyPreferences: legacyPreferences,
                );
            processDatabaseLease = databaseLease;
            businessPreferences = loadedBusinessPreferences;
          } catch (_) {
            await databaseLease.release();
            rethrow;
          }
          break;
        } catch (error, stackTrace) {
          stderr.writeln('[DatabaseAdmission] $error\n$stackTrace');
          if (!recoveryAttempted) {
            recoveryAttempted = true;
            final recovery = await _recoverFailedAdmission(
              appDataDirectory,
              error,
            );
            if (recovery == _AdmissionRecovery.remigrate) {
              runApp(
                MigrationApp(
                  service: HiveToSqliteMigrationService(
                    _legacyMigrationDecision(appDataDirectory),
                  ),
                  restoreOutcome: restoreOutcome?.state,
                ),
              );
              return;
            }
            if (recovery == _AdmissionRecovery.rebuilt) {
              continue;
            }
          }
          await _initRestoreFailureWindow();
          runApp(
            _RestoreFailureApp(
              report: StartupFailureReport.capture(
                stage: StartupFailureStage.databaseAdmission,
                error: error,
                step: admissionStep,
                stackTrace: stackTrace,
              ),
              appDataDirectory: appDataDirectory,
            ),
          );
          return;
        }
      }
      // Desktop exit hook: drain queued preference writes before process exit.
      _installExitFlush(businessPreferences);
      // Best-effort trim of archived restore runs after a few cold starts.
      unawaited(_pruneRestoreArchive(appDataDirectory));
      // Enable edge-to-edge to allow content under system bars (Android)
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // Start app (Flutter log capture is toggleable and off by default)
      runApp(
        MyApp(
          databaseLease: processDatabaseLease,
          businessPreferences: businessPreferences,
          appDataDirectory: appDataDirectory,
          restoreOutcome: restoreOutcome?.state,
        ),
      );
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        FlutterLogger.logPrint(line);
        parent.print(zone, line);
      },
    ),
  );
}

enum _AdmissionRecovery { none, rebuilt, remigrate }

/// Names must mirror HiveToSqliteMigrationService.check().
const _legacyHiveSourceNames = <String>[
  'conversations.hive',
  'messages.hive',
  'tool_events_v1.hive',
];

bool _legacyHiveSourcesExist(Directory appDataDirectory) =>
    _legacyHiveSourceNames.any(
      (name) => File('${appDataDirectory.path}/$name').existsSync(),
    );

Future<_AdmissionRecovery> _recoverFailedAdmission(
  Directory appDataDirectory,
  Object error,
) async {
  final action = await DatabaseInstallationGate.recoveryActionFor(
    appDataDirectory: appDataDirectory,
    error: error,
    legacyHiveDataPresent: _legacyHiveSourcesExist(appDataDirectory),
  );
  switch (action) {
    case DatabaseRecoveryAction.rebuildAutomatically:
      try {
        // The only route that destroys state without anyone confirming it, so
        // it is the only one that has to leave a record of itself. A user who
        // finds the app empty otherwise has nothing to report but the symptom.
        await _recordAutomaticRebuild(appDataDirectory, error);
        await DatabaseInstallationGate.rebuildFresh(
          appDataDirectory: appDataDirectory,
        );
        return _AdmissionRecovery.rebuilt;
      } catch (rebuildError, rebuildStack) {
        stderr.writeln(
          '[DatabaseAdmission] rebuild failed: $rebuildError\n$rebuildStack',
        );
        return _AdmissionRecovery.none;
      }
    case DatabaseRecoveryAction.promptRemigration:
      return _AdmissionRecovery.remigrate;
    case DatabaseRecoveryAction.promptUpgrade:
    case DatabaseRecoveryAction.none:
      return _AdmissionRecovery.none;
  }
}

/// Appends a record of an unattended rebuild to `logs/`.
///
/// Deliberately independent of the Flutter log capture toggle, which is off by
/// default: this is the one startup outcome that silently destroys state, and
/// a user who finds the app empty has nothing else to report. The listing is
/// taken before the rebuild, so it still describes the files it is about to
/// clear. Best-effort throughout — a rebuild must not fail for want of a note.
Future<void> _recordAutomaticRebuild(
  Directory appDataDirectory,
  Object error,
) async {
  try {
    var report = StartupFailureReport.capture(
      stage: StartupFailureStage.databaseAdmission,
      error: error,
      step: 'automatic_rebuild',
    );
    try {
      report = report.withEnvironment(
        await StartupFailureEnvironment.collect(
          appDataDirectory: appDataDirectory,
        ),
      );
    } catch (_) {}
    final logs = Directory('${appDataDirectory.path}/logs');
    await logs.create(recursive: true);
    await File('${logs.path}/$startupRecoveryLogFileName').writeAsString(
      '${report.toText()}\n\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {}
}

HiveToSqliteMigrationDecision _legacyMigrationDecision(
  Directory appDataDirectory,
) {
  return HiveToSqliteMigrationDecision(
    needsMigration: true,
    appDataDir: appDataDirectory,
    sqliteFile: File(
      '${appDataDirectory.path}/${AppDatabase.databaseFileName}',
    ),
    hiveFiles: [
      for (final name in _legacyHiveSourceNames)
        if (File('${appDataDirectory.path}/$name').existsSync())
          File('${appDataDirectory.path}/$name'),
    ],
  );
}

Future<void> _initRestoreFailureWindow() async {
  if (kIsWeb) return;
  final isDesktop =
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
  if (!isDesktop) return;
  try {
    await windowManager.ensureInitialized();
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.show();
      await windowManager.focus();
      return;
    }
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(title: 'Kelivo'),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  } catch (error) {
    stderr.writeln('[RestoreFailureWindow] $error');
  }
}

class _RestoreFailureApp extends StatelessWidget {
  const _RestoreFailureApp({required this.report, this.appDataDirectory});

  final StartupFailureReport report;
  final Directory? appDataDirectory;

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalettes.defaultPalette;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kelivo',
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildLightThemeForScheme(palette.light),
      darkTheme: buildDarkThemeForScheme(palette.dark),
      home: report.diagnosticCode == 'database_schema_too_new'
          ? UpdateRequiredScreen(diagnosticCode: report.diagnosticCode)
          : RestoreFailureScreen(
              report: report,
              restart: PlatformUtils.restartApp,
              appDataDirectory: appDataDirectory,
            ),
    );
  }
}

Future<void> _initDesktopWindow() async {
  if (kIsWeb) return;
  try {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      await windowManager.ensureInitialized();
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    // Initialize and show desktop window with persisted size/position
    await DesktopWindowController.instance.initializeAndShow(title: 'Kelivo');
  } catch (_) {
    // Ignore on unsupported platforms.
  }
}

// Removed eager system font preloading to reduce memory footprint at launch.

AppLifecycleListener? _exitFlushListener;

/// Desktop-only: mobile process kills cannot be intercepted, and SQLite WAL
/// already protects committed transactions, so only Dart-side write queues
/// need draining before exit.
void _installExitFlush(BusinessPreferences businessPreferences) {
  if (kIsWeb) return;
  final isDesktop =
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
  if (!isDesktop || _exitFlushListener != null) return;
  AppExitFlush.register(businessPreferences.flushPendingWrites);
  AppExitFlush.register(ChatActions.flushActiveGenerationProgress);
  _exitFlushListener = AppLifecycleListener(
    onExitRequested: () async {
      try {
        // Bound the wait: a stuck write transaction must not leave the
        // process unkillable after macOS answers NSTerminateLater.
        await AppExitFlush.flushAll().timeout(
          const Duration(seconds: 2),
          onTimeout: () {},
        );
      } catch (_) {}
      return AppExitResponse.exit;
    },
  );
}

Future<void> _pruneRestoreArchive(Directory appDataDirectory) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    const key = RestoreArchivePruner.coldStartsKey;
    await RestoreArchivePruner(
      appDataDirectory: appDataDirectory,
      readColdStarts: () async => prefs.getInt(key) ?? 0,
      writeColdStarts: (count) => prefs.setInt(key, count),
    ).pruneAfterSuccessfulColdStart();
  } catch (_) {}
}

class MigrationApp extends StatelessWidget {
  const MigrationApp({super.key, required this.service, this.restoreOutcome});

  final HiveToSqliteMigrationService service;
  final RestoreReceiptState? restoreOutcome;

  @override
  Widget build(BuildContext context) {
    final palette = ThemePalettes.defaultPalette;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kelivo',
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildLightThemeForScheme(palette.light),
      darkTheme: buildDarkThemeForScheme(palette.dark),
      builder: (context, child) =>
          AppSnackBarOverlay(child: child ?? const SizedBox.shrink()),
      home: RestoreOutcomeNotice(
        outcome: restoreOutcome,
        child: HiveToSqliteMigrationPage(service: service),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.databaseLease,
    required this.businessPreferences,
    required this.appDataDirectory,
    this.restoreOutcome,
  });

  final ChatDatabaseLease databaseLease;
  final BusinessPreferences businessPreferences;
  final Directory appDataDirectory;
  final RestoreReceiptState? restoreOutcome;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<BusinessRepository>.value(
          value: databaseLease.businessRepository,
        ),
        Provider<BusinessPreferences>.value(value: businessPreferences),
        ChangeNotifierProvider(
          create: (_) => UserProvider(preferences: businessPreferences),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final settings = SettingsProvider(businessPreferences);
            unawaited(
              settings.loaded.then((_) => settings.incrementAppLaunchCount()),
            );
            return settings;
          },
        ),
        ChangeNotifierProvider(
          create: (_) =>
              ChatService(existingRepository: databaseLease.chatRepository),
        ),
        ChangeNotifierProvider(create: (_) => McpToolService()),
        ChangeNotifierProvider(
          create: (_) => McpProvider(preferences: businessPreferences),
        ),
        ChangeNotifierProvider(create: (_) => ToolApprovalService()),
        ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
        ChangeNotifierProvider(
          create: (ctx) => AssistantProvider(
            preferences: businessPreferences,
            chatService: ctx.read<ChatService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => TagProvider(preferences: businessPreferences),
        ),
        ChangeNotifierProvider(
          create: (_) => TtsProvider(preferences: businessPreferences),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              AsrProvider(settingsProvider: ctx.read<SettingsProvider>()),
        ),
        ChangeNotifierProvider(create: (_) => UpdateProvider()),
        ChangeNotifierProvider(
          create: (_) => QuickPhraseProvider(preferences: businessPreferences),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              InstructionInjectionProvider(preferences: businessPreferences),
        ),
        ChangeNotifierProvider(
          create: (_) => InstructionInjectionGroupProvider(
            preferences: businessPreferences,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WorldBookProvider(preferences: businessPreferences),
        ),
        ChangeNotifierProvider(
          create: (_) => MemoryProvider(preferences: businessPreferences),
        ),
        ChangeNotifierProvider(
          create: (_) => MemoryProviderV2(
            repository: MemoryRepository(businessPreferences),
            chatRepository: databaseLease.chatRepository,
          ),
        ),
        Provider<MemoryPipelineService>(
          create: (ctx) {
            final memoryV2 = ctx.read<MemoryProviderV2>();
            return MemoryPipelineService(
              chatService: ctx.read<ChatService>(),
              repository: memoryV2.repository,
              chatRepository: memoryV2.chatRepository,
              settings: () => ctx.read<SettingsProvider>(),
              assistants: () => ctx.read<AssistantProvider>(),
              memoryV2: () => ctx.read<MemoryProviderV2>(),
            );
          },
        ),
        ChangeNotifierProvider(
          create: (_) =>
              BackupReminderProvider(preferences: businessPreferences),
        ),
        // Desktop hotkeys provider
        ChangeNotifierProvider(create: (_) => HotkeyProvider()),
        ChangeNotifierProvider(
          create: (ctx) => BackupProvider(
            chatService: ctx.read<ChatService>(),
            businessRepository: databaseLease.businessRepository,
            businessPreferences: businessPreferences,
            initialConfig: ctx.read<SettingsProvider>().webDavConfig,
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => S3BackupProvider(
            chatService: ctx.read<ChatService>(),
            businessRepository: databaseLease.businessRepository,
            businessPreferences: businessPreferences,
            initialConfig: ctx.read<SettingsProvider>().s3Config,
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => LocalSnapshotProvider(
            appDataDirectory: appDataDirectory,
            chatService: ctx.read<ChatService>(),
            businessRepository: databaseLease.businessRepository,
            businessPreferences: businessPreferences,
            isBusy: () {
              // Never compete with a reply the user is watching, nor with a
              // backup, restore or import that is already holding the
              // database. Asked of the process-wide tracker rather than of the
              // providers here: the mobile backup screen builds its own
              // instances, so these root ones stay idle throughout a mobile
              // backup, and a local-file restore never marks them busy at all.
              if (ChatActions.hasAnyActiveGeneration) {
                return LocalSnapshotSkipReason.generating;
              }
              if (BackupActivity.isActive ||
                  ctx.read<BackupProvider>().busy ||
                  ctx.read<S3BackupProvider>().busy) {
                return LocalSnapshotSkipReason.busy;
              }
              return null;
            },
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          final settings = context.watch<SettingsProvider>();
          // Apply global proxy overrides when settings change
          settings.applyGlobalProxyOverridesIfNeeded();
          // Lazily ensure system fonts only if user selected a system family (desktop only)
          // Load ONLY selected families to avoid huge memory from loading all system fonts.
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            try {
              final isDesktop =
                  !kIsWeb &&
                  (defaultTargetPlatform == TargetPlatform.windows ||
                      defaultTargetPlatform == TargetPlatform.macOS ||
                      defaultTargetPlatform == TargetPlatform.linux);
              if (!isDesktop) return;
              // Selected system app/code fonts (not local alias)
              final wantsAppSystem =
                  (settings.appFontFamily?.isNotEmpty == true) &&
                  (settings.appFontLocalAlias == null ||
                      settings.appFontLocalAlias!.isEmpty);
              final wantsCodeSystem =
                  (settings.codeFontFamily?.isNotEmpty == true) &&
                  (settings.codeFontLocalAlias == null ||
                      settings.codeFontLocalAlias!.isEmpty);
              if (wantsAppSystem || wantsCodeSystem) {
                final sf = SystemFonts();
                if (wantsAppSystem) {
                  final fam = settings.appFontFamily!;
                  try {
                    await sf.loadFont(fam);
                  } catch (_) {}
                }
                if (wantsCodeSystem) {
                  final fam = settings.codeFontFamily!;
                  try {
                    if (fam != settings.appFontFamily) await sf.loadFont(fam);
                  } catch (_) {}
                }
              }
            } catch (_) {}
          });
          // One-time app update check after first build
          if (settings.showAppUpdates && !_didCheckUpdates) {
            _didCheckUpdates = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                await settings.loaded;
                if (!context.mounted || !settings.showAppUpdates) return;
                await context.read<UpdateProvider>().checkForUpdates();
              } catch (_) {}
            });
          }
          return DynamicColorBuilder(
            builder: (lightDynamic, darkDynamic) {
              // if (lightDynamic != null) {
              //   debugPrint('[DynamicColor] Light dynamic detected. primary=${lightDynamic.primary.value.toRadixString(16)} surface=${lightDynamic.surface.value.toRadixString(16)}');
              // } else {
              //   debugPrint('[DynamicColor] Light dynamic not available');
              // }
              // if (darkDynamic != null) {
              //   debugPrint('[DynamicColor] Dark dynamic detected. primary=${darkDynamic.primary.value.toRadixString(16)} surface=${darkDynamic.surface.value.toRadixString(16)}');
              // } else {
              //   debugPrint('[DynamicColor] Dark dynamic not available');
              // }
              final isAndroid =
                  Theme.of(context).platform == TargetPlatform.android;
              // Update dynamic color capability for settings UI (avoid notify during build)
              final dynSupported =
                  isAndroid && (lightDynamic != null || darkDynamic != null);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  settings.setDynamicColorSupported(dynSupported);
                } catch (_) {}
              });

              // Initialize desktop hotkeys on supported platforms
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  final isDesktop =
                      !kIsWeb &&
                      (defaultTargetPlatform == TargetPlatform.windows ||
                          defaultTargetPlatform == TargetPlatform.macOS ||
                          defaultTargetPlatform == TargetPlatform.linux);
                  if (isDesktop) {
                    await context.read<HotkeyProvider>().initialize();
                  }
                } catch (_) {}
              });

              // Android-only: ensure background execution matches setting and prepare notifications if needed
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  if (Platform.isAndroid) {
                    final mode = settings.androidBackgroundChatMode;
                    if (mode != AndroidBackgroundChatMode.off) {
                      final l10n = AppLocalizations.of(context);
                      if (l10n == null) return;
                      // Enable only if currently disabled to avoid duplicate ROM prompts
                      try {
                        final already =
                            await AndroidBackgroundManager.isEnabled();
                        if (!already) {
                          await AndroidBackgroundManager.ensureInitialized(
                            notificationTitle:
                                l10n.androidBackgroundNotificationTitle,
                            notificationText:
                                l10n.androidBackgroundNotificationText,
                          );
                          await AndroidBackgroundManager.setEnabled(true);
                        }
                      } catch (_) {}
                      if (mode == AndroidBackgroundChatMode.onNotify) {
                        await NotificationService.ensureAndroidNotificationsPermission();
                      }
                    }
                  }
                } catch (_) {}
              });

              final useDyn = isAndroid && settings.useDynamicColor;
              final custom = settings.selectedCustomTheme;
              final palette =
                  settings.themePaletteId == ThemePalettes.customPaletteId &&
                      custom != null
                  ? buildCustomThemePalette(custom)
                  : ThemePalettes.byId(settings.themePaletteId);

              final light = buildLightThemeForScheme(
                palette.light,
                dynamicScheme: useDyn ? lightDynamic : null,
                pureBackground: settings.usePureBackground,
                layeredSurfaces: settings.useLayeredSurfaces,
              );
              final dark = buildDarkThemeForScheme(
                palette.dark,
                dynamicScheme: useDyn ? darkDynamic : null,
                pureBackground: settings.usePureBackground,
                layeredSurfaces: settings.useLayeredSurfaces,
              );
              // Resolve effective app font family (system/local alias)
              String? effectiveAppFontFamily() {
                final fam = settings.appFontFamily;
                if (fam == null || fam.isEmpty) return null;
                return fam;
              }

              final effectiveAppFont = effectiveAppFontFamily();

              // Apply user-selected app font to theme text styles and app bar
              ThemeData applyAppFont(ThemeData base) {
                if (effectiveAppFont == null || effectiveAppFont.isEmpty) {
                  return base;
                }
                TextStyle? withFamily(TextStyle? s) =>
                    s?.copyWith(fontFamily: effectiveAppFont);
                TextTheme apply(TextTheme t) => t.copyWith(
                  displayLarge: withFamily(t.displayLarge),
                  displayMedium: withFamily(t.displayMedium),
                  displaySmall: withFamily(t.displaySmall),
                  headlineLarge: withFamily(t.headlineLarge),
                  headlineMedium: withFamily(t.headlineMedium),
                  headlineSmall: withFamily(t.headlineSmall),
                  titleLarge: withFamily(t.titleLarge),
                  titleMedium: withFamily(t.titleMedium),
                  titleSmall: withFamily(t.titleSmall),
                  bodyLarge: withFamily(t.bodyLarge),
                  bodyMedium: withFamily(t.bodyMedium),
                  bodySmall: withFamily(t.bodySmall),
                  labelLarge: withFamily(t.labelLarge),
                  labelMedium: withFamily(t.labelMedium),
                  labelSmall: withFamily(t.labelSmall),
                );
                final bar = base.appBarTheme;
                final appBar = bar.copyWith(
                  titleTextStyle: (bar.titleTextStyle ?? const TextStyle())
                      .copyWith(fontFamily: effectiveAppFont),
                  toolbarTextStyle: (bar.toolbarTextStyle ?? const TextStyle())
                      .copyWith(fontFamily: effectiveAppFont),
                );
                // Apply as default family to all text in ThemeData
                return base.copyWith(
                  textTheme: apply(base.textTheme),
                  primaryTextTheme: apply(base.primaryTextTheme),
                  appBarTheme: appBar,
                );
              }

              final themedLight = applyAppFont(light);
              final themedDark = applyAppFont(dark);
              // Log top-level colors likely used by widgets (card/bg/shadow approximations)
              // debugPrint('[Theme/App] Light scaffoldBg=${light.colorScheme.surface.value.toRadixString(16)} card≈${light.colorScheme.surface.value.toRadixString(16)} shadow=${light.colorScheme.shadow.value.toRadixString(16)}');
              // debugPrint('[Theme/App] Dark scaffoldBg=${dark.colorScheme.surface.value.toRadixString(16)} card≈${dark.colorScheme.surface.value.toRadixString(16)} shadow=${dark.colorScheme.shadow.value.toRadixString(16)}');
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'Kelivo',
                navigatorKey: rootNavigatorKey,
                // App UI language; null = follow system (respects iOS per-app language)
                locale: settings.appLocaleForMaterialApp,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                theme: themedLight,
                darkTheme: themedDark,
                themeMode: settings.themeMode,
                navigatorObservers: <NavigatorObserver>[routeObserver],
                home: RestoreOutcomeNotice(
                  outcome: restoreOutcome,
                  child: _selectHome(),
                ),
                builder: (ctx, child) {
                  final bright = Theme.of(ctx).brightness;
                  // Keep the native window background in sync with the app
                  // surface color so that resizing (driven by window_manager's
                  // DragToResizeArea) doesn't flash a black region while the
                  // Flutter canvas catches up. Matches v2rayN's solid border.
                  final surface = Theme.of(ctx).colorScheme.surface;
                  if (_lastWindowBg?.toARGB32() != surface.toARGB32()) {
                    try {
                      windowManager.setBackgroundColor(surface);
                      _lastWindowBg = surface;
                    } catch (_) {
                      // Not ready yet; retry on next rebuild.
                    }
                  }
                  final overlay = bright == Brightness.dark
                      ? const SystemUiOverlayStyle(
                          statusBarColor: Colors.transparent,
                          statusBarIconBrightness: Brightness.light,
                          statusBarBrightness: Brightness.dark,
                          systemNavigationBarColor: Colors.transparent,
                          systemNavigationBarIconBrightness: Brightness.light,
                          systemNavigationBarDividerColor: Colors.transparent,
                          systemNavigationBarContrastEnforced: false,
                        )
                      : const SystemUiOverlayStyle(
                          statusBarColor: Colors.transparent,
                          statusBarIconBrightness: Brightness.dark,
                          statusBarBrightness: Brightness.light,
                          systemNavigationBarColor: Colors.transparent,
                          systemNavigationBarIconBrightness: Brightness.dark,
                          systemNavigationBarDividerColor: Colors.transparent,
                          systemNavigationBarContrastEnforced: false,
                        );
                  // Ensure localized defaults (assistants and chat default title) after first frame
                  if (!_didEnsureAssistants) {
                    _didEnsureAssistants = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      try {
                        ctx.read<AssistantProvider>().ensureDefaults(ctx);
                      } catch (_) {}
                      try {
                        ctx.read<ChatService>().setDefaultConversationTitle(
                          AppLocalizations.of(
                            ctx,
                          )!.chatServiceDefaultConversationTitle,
                        );
                      } catch (_) {}
                      try {
                        ctx.read<UserProvider>().setDefaultNameIfUnset(
                          AppLocalizations.of(ctx)!.userProviderDefaultUserName,
                        );
                      } catch (_) {}
                    });
                  }

                  // Desktop tray + close behaviour (minimize to tray) sync
                  final l10n = AppLocalizations.of(ctx);
                  if (l10n != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      try {
                        final isDesktop =
                            !kIsWeb &&
                            (defaultTargetPlatform == TargetPlatform.windows ||
                                defaultTargetPlatform == TargetPlatform.macOS ||
                                defaultTargetPlatform == TargetPlatform.linux);
                        if (!isDesktop) return;
                        final sp = ctx.read<SettingsProvider>();
                        await DesktopTrayController.instance.syncFromSettings(
                          l10n,
                          showTray: sp.desktopShowTray,
                          minimizeToTrayOnClose:
                              sp.desktopMinimizeToTrayOnClose,
                        );
                      } catch (_) {}
                    });
                  }

                  final mq = MediaQuery.of(ctx);
                  final display = View.of(ctx).display;
                  final displaySize = display.size / display.devicePixelRatio;
                  final isFloatingIpad =
                      defaultTargetPlatform == TargetPlatform.iOS &&
                      displaySize.shortestSide >= 600 &&
                      (mq.size.shortestSide < displaySize.shortestSide - 1 ||
                          mq.size.longestSide < displaySize.longestSide - 1);
                  final systemTop = mq.viewPadding.top;
                  final controlsTop = systemTop < 56 ? 56.0 : systemTop;
                  final appWithOverlays = MediaQuery(
                    data: isFloatingIpad
                        ? mq.copyWith(
                            padding: mq.padding.copyWith(top: controlsTop),
                            viewPadding: mq.viewPadding.copyWith(
                              top: controlsTop,
                            ),
                          )
                        : mq,
                    child: LocalSnapshotScheduler(
                      child: AppOverlays(
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  );
                  // Enforce app font as a default across the tree for Texts without explicit family
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: overlay,
                    child: effectiveAppFont == null
                        ? appWithOverlays
                        : DefaultTextStyle.merge(
                            style: TextStyle(fontFamily: effectiveAppFont),
                            child: appWithOverlays,
                          ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

Widget _selectHome() {
  // Mobile remains the default platform. Desktop is an added platform.
  if (kIsWeb) return const HomePage();
  final isDesktop =
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
  return isDesktop ? const DesktopHomePage() : const HomePage();
}

// Overrides logic is implemented within SettingsProvider now.
