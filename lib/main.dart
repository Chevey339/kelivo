import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
// import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'features/home/pages/home_page.dart';
import 'desktop/desktop_home_page.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'desktop/desktop_window_controller.dart';
import 'utils/platform_utils.dart';
// import 'package:logging/logging.dart' as logging;
// Theme is now managed in SettingsProvider
import 'theme/theme_factory.dart';
import 'theme/palettes.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'core/providers/chat_provider.dart';
import 'core/providers/user_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/mcp_provider.dart';
import 'core/providers/tts_provider.dart';
import 'core/providers/assistant_provider.dart';
import 'core/providers/update_provider.dart';
import 'core/providers/quick_phrase_provider.dart';
import 'core/providers/memory_provider.dart';
import 'core/services/chat/chat_service.dart';
import 'core/services/mcp/mcp_tool_service.dart';
import 'utils/sandbox_path_resolver.dart';
import 'shared/widgets/snackbar.dart';

final RouteObserver<ModalRoute<dynamic>> routeObserver = RouteObserver<ModalRoute<dynamic>>();
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
bool _didCheckUpdates = false; // one-time update check flag
bool _didEnsureAssistants = false; // ensure defaults after l10n ready


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Desktop (Windows) window setup: hide native title bar for custom Flutter bar
  await _initDesktopWindow();
  // Debug logging and global error handlers were enabled previously for diagnosis.
  // They are commented out now per request to reduce log noise.
  // FlutterError.onError = (FlutterErrorDetails details) { ... };
  // WidgetsBinding.instance.platformDispatcher.onError = (Object error, StackTrace stack) { ... };
  // logging.Logger.root.level = logging.Level.ALL;
  // logging.Logger.root.onRecord.listen((rec) { ... });
  // Cache current Documents directory to fix sandboxed absolute paths on iOS
  await SandboxPathResolver.init();
  // Enable edge-to-edge to allow content under system bars (Android)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Start app (no extra guarded zone logging)
runApp(const MyApp());
}

Future<void> _initDesktopWindow() async {
  if (kIsWeb || !PlatformUtils.isDesktop) return;
  
  try {
    if (PlatformUtils.isWindows) {
      // Windows-specific initialization
      await PlatformUtils.callPlatformMethod(() async {
        await windowManager.ensureInitialized();
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      });
    }
    // Initialize and show desktop window with persisted size/position
    await DesktopWindowController.instance.initializeAndShow(title: 'Kelivo');
  } catch (e) {
    debugPrint('Desktop window initialization failed: $e');
  }
}

class BackIntent extends Intent {
  const BackIntent();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => McpToolService()),
        ChangeNotifierProvider(create: (_) => McpProvider()),
        ChangeNotifierProvider(create: (_) => AssistantProvider()),
        ChangeNotifierProvider(create: (_) => TtsProvider()),
        ChangeNotifierProvider(create: (_) => UpdateProvider()),
        ChangeNotifierProvider(create: (_) => QuickPhraseProvider()),
        ChangeNotifierProvider(create: (_) => MemoryProvider()),
      ],
      child: Builder(
        builder: (context) {
          final settings = context.watch<SettingsProvider>();
          // One-time app update check after first build
          if (settings.showAppUpdates && !_didCheckUpdates) {
            _didCheckUpdates = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try { context.read<UpdateProvider>().checkForUpdates(); } catch (_) {}
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
              final isAndroid = Theme.of(context).platform == TargetPlatform.android;
              // Update dynamic color capability for settings UI (avoid notify during build)
              final dynSupported = isAndroid && (lightDynamic != null || darkDynamic != null);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  settings.setDynamicColorSupported(dynSupported);
                } catch (_) {}
              });

              final useDyn = isAndroid && settings.useDynamicColor;
              final palette = ThemePalettes.byId(settings.themePaletteId);

              final light = buildLightThemeForScheme(
                palette.light,
                dynamicScheme: useDyn ? lightDynamic : null,
              );
              final dark = buildDarkThemeForScheme(
                palette.dark,
                dynamicScheme: useDyn ? darkDynamic : null,
              );
              // Log top-level colors likely used by widgets (card/bg/shadow approximations)
              // debugPrint('[Theme/App] Light scaffoldBg=${light.colorScheme.surface.value.toRadixString(16)} card≈${light.colorScheme.surface.value.toRadixString(16)} shadow=${light.colorScheme.shadow.value.toRadixString(16)}');
              // debugPrint('[Theme/App] Dark scaffoldBg=${dark.colorScheme.surface.value.toRadixString(16)} card≈${dark.colorScheme.surface.value.toRadixString(16)} shadow=${dark.colorScheme.shadow.value.toRadixString(16)}');
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'Kelivo',
                navigatorKey: appNavigatorKey,
                // App UI language; null = follow system (respects iOS per-app language)
                locale: settings.appLocaleForMaterialApp,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                theme: light,
                darkTheme: dark,
                themeMode: settings.themeMode,
                navigatorObservers: <NavigatorObserver>[routeObserver],
                home: _selectHome(),
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
                  try { ctx.read<AssistantProvider>().ensureDefaults(ctx); } catch (_) {}
                  try { ctx.read<ChatService>().setDefaultConversationTitle(AppLocalizations.of(ctx)!.chatServiceDefaultConversationTitle); } catch (_) {}
                  try { ctx.read<UserProvider>().setDefaultNameIfUnset(AppLocalizations.of(ctx)!.userProviderDefaultUserName); } catch (_) {}
                });
              }

                  return Shortcuts(
                    shortcuts: <LogicalKeySet, Intent>{
                      // ESC: close dialog/sheet or pop route
                      LogicalKeySet(LogicalKeyboardKey.escape): const BackIntent(),
                      // Ctrl+W: common desktop close-tab/back gesture
                      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyW): const BackIntent(),
                    },
                    child: Actions(
                      actions: <Type, Action<Intent>>{
                        BackIntent: CallbackAction<BackIntent>(
                          onInvoke: (intent) {
                            final nav = appNavigatorKey.currentState;
                            nav?.maybePop();
                            return null;
                          },
                        ),
                      },
                      child: Focus(
                        autofocus: true,
                        child: AnnotatedRegion<SystemUiOverlayStyle>(
                          value: overlay,
                          child: AppSnackBarOverlay(
                            child: child ?? const SizedBox.shrink(),
                          ),
                        ),
                      ),
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
  final isDesktop = defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
  return isDesktop ? const DesktopHomePage() : const HomePage();
}
 
