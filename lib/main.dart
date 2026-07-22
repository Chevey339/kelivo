import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:async';
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
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'core/providers/user_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/mcp_provider.dart';
import 'core/providers/tts_provider.dart';
import 'core/providers/assistant_provider.dart';
import 'core/providers/tag_provider.dart';
import 'core/providers/update_provider.dart';
import 'core/providers/quick_phrase_provider.dart';
import 'core/providers/instruction_injection_provider.dart';
import 'core/providers/instruction_injection_group_provider.dart';
import 'core/providers/world_book_provider.dart';
import 'core/providers/memory_provider.dart';
import 'core/providers/backup_provider.dart';
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
import 'core/services/chat/chat_service.dart';
import 'core/services/database_v2_rollout_ledger.dart';
import 'core/services/backup/restore_business_lease.dart';
import 'core/services/backup/restore_startup_gate.dart';
import 'core/services/backup/restore_receipt.dart';
import 'core/services/mcp/mcp_tool_service.dart';
import 'core/services/logging/flutter_logger.dart';
import 'features/home/services/ask_user_interaction_service.dart';
import 'features/home/services/tool_approval_service.dart';
import 'utils/app_directories.dart';
import 'utils/platform_utils.dart';
import 'utils/sandbox_path_resolver.dart';
import 'shared/widgets/app_overlays.dart';
import 'shared/widgets/snackbar.dart';
import 'shared/widgets/restore_failure_screen.dart';
import 'shared/widgets/restore_outcome_notice.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:system_fonts/system_fonts.dart';
import 'dart:io'
    show
        File,
        Platform,
        pid,
        stderr; // kept for global override usage inside provider
import 'core/services/android_background.dart';
import 'core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final RouteObserver<ModalRoute<dynamic>> routeObserver =
    RouteObserver<ModalRoute<dynamic>>();
bool _didCheckUpdates = false; // one-time update check flag
bool _didEnsureAssistants = false; // ensure defaults after l10n ready

Future<void> main() async {
  await runZoned(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
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
            diagnosticCode: restoreFailureDiagnosticCode(error),
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
      try {
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
        final installationReceipt = await DatabaseInstallationGate.ensureReady(
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
        final databaseLease = await ChatDatabaseGateway.instance.acquire(
          databaseFile,
        );
        try {
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
        try {
          final rollout = DatabaseV2RolloutLedger.rolloutDecision(
            installationId: installationReceipt.installationId,
            enabledBasisPoints: const int.fromEnvironment(
              'KELIVO_DATABASE_V2_ROLLOUT_BASIS_POINTS',
              defaultValue: 10000,
            ),
          );
          if (rollout.enabled) {
            await DatabaseV2RolloutLedger(
              appDataDirectory,
            ).recordSuccessfulColdStart(
              coldStartId:
                  '$pid:${DateTime.now().toUtc().microsecondsSinceEpoch}',
              atUtc: DateTime.now().toUtc(),
            );
          }
        } catch (error) {
          // Local rollout evidence is support/retirement metadata. The
          // database admission result remains authoritative; a ledger failure
          // keeps legacy cleanup disabled instead of blocking the user.
          stderr.writeln('[DatabaseV2Rollout] $error');
        }
      } catch (error, stackTrace) {
        stderr.writeln('[DatabaseAdmission] $error\n$stackTrace');
        await _initRestoreFailureWindow();
        runApp(
          _RestoreFailureApp(
            diagnosticCode: restoreFailureDiagnosticCode(error),
          ),
        );
        return;
      }
      // Enable edge-to-edge to allow content under system bars (Android)
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // Start app (Flutter log capture is toggleable and off by default)
      runApp(
        MyApp(
          databaseLease: processDatabaseLease,
          businessPreferences: businessPreferences,
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
  const _RestoreFailureApp({required this.diagnosticCode});

  final String diagnosticCode;

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
      home: RestoreFailureScreen(
        diagnosticCode: diagnosticCode,
        restart: PlatformUtils.restartApp,
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
    this.restoreOutcome,
  });

  final ChatDatabaseLease databaseLease;
  final BusinessPreferences businessPreferences;
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
          create: (ctx) => BackupReminderProvider(
            preferences: businessPreferences,
            backupProvider: ctx.read<BackupProvider>(),
            webDavConfig: ctx.read<SettingsProvider>().webDavConfig,
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
              // Selected system app/code fonts (not Google, not local alias)
              final wantsAppSystem =
                  (settings.appFontFamily?.isNotEmpty == true) &&
                  !settings.appFontIsGoogle &&
                  (settings.appFontLocalAlias == null ||
                      settings.appFontLocalAlias!.isEmpty);
              final wantsCodeSystem =
                  (settings.codeFontFamily?.isNotEmpty == true) &&
                  !settings.codeFontIsGoogle &&
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                context.read<UpdateProvider>().checkForUpdates();
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
                        await NotificationService.ensureInitialized();
                        await NotificationService.ensureAndroidNotificationsPermission();
                      }
                    }
                  }
                } catch (_) {}
              });

              final useDyn = isAndroid && settings.useDynamicColor;
              final palette = ThemePalettes.byId(settings.themePaletteId);

              final light = buildLightThemeForScheme(
                palette.light,
                dynamicScheme: useDyn ? lightDynamic : null,
                pureBackground: settings.usePureBackground,
              );
              final dark = buildDarkThemeForScheme(
                palette.dark,
                dynamicScheme: useDyn ? darkDynamic : null,
                pureBackground: settings.usePureBackground,
              );
              // Resolve effective app font family (system/Google/local alias)
              String? effectiveAppFontFamily() {
                final fam = settings.appFontFamily;
                if (fam == null || fam.isEmpty) return null;
                if (settings.appFontIsGoogle) {
                  try {
                    final s = GoogleFonts.getFont(fam);
                    return s.fontFamily ?? fam;
                  } catch (_) {
                    return fam;
                  }
                }
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
                    child: AppOverlays(child: child ?? const SizedBox.shrink()),
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
