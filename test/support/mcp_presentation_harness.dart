import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/models/mcp_presentation.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/palettes.dart';

import 'business_test_harness.dart';

class PresentationMcpProvider extends McpProvider {
  PresentationMcpProvider({required super.preferences});

  List<McpServerConfig> items = [];
  bool rejectRemoval = false;
  Future<void>? reconnectWait;
  Future<void>? reorderWait;
  Future<String>? groupCreation;
  int groupCreationStarted = 0;
  int reorderStarted = 0;
  int? groupReorderTarget;
  final restoredPresentations = <String, McpServerPresentation>{};

  @override
  Future<String> createGroup(String name) {
    groupCreationStarted++;
    return groupCreation ?? super.createGroup(name);
  }

  @override
  Future<bool> reconnect(String id) async {
    await reconnectWait;
    statuses[id] = McpStatus.connected;
    notifyListeners();
    return true;
  }

  @override
  Future<void> restoreServer(
    McpServerConfig server,
    McpServerPresentation presentation,
  ) async {
    items = [...items, server];
    restoredPresentations[server.id] = presentation;
    notifyListeners();
  }

  final Map<String, McpStatus> statuses = {};
  final Map<String, String> errors = {};

  @override
  List<McpServerConfig> get servers => items;

  @override
  McpServerConfig? getById(String id) =>
      items.where((server) => server.id == id).firstOrNull;

  @override
  McpStatus statusFor(String id) => statuses[id] ?? McpStatus.connected;

  @override
  String? errorFor(String id) => errors[id];

  @override
  Future<void> updateServerMetadata(
    McpServerConfig updated, {
    bool replaceOAuthSettings = false,
  }) async {
    items = [
      for (final server in items)
        if (server.id == updated.id) updated else server,
    ];
    notifyListeners();
  }

  @override
  Future<void> reorderServers(int oldIndex, int newIndex) async {
    reorderStarted++;
    await reorderWait;
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    notifyListeners();
  }

  @override
  Future<void> reorderGroup(String id, int newIndex) async {
    reorderStarted++;
    groupReorderTarget = newIndex;
    await reorderWait;
    await super.reorderGroup(id, newIndex);
  }

  @override
  Future<void> removeServer(String id) async {
    if (rejectRemoval) throw StateError('Storage unavailable');
    items = items.where((server) => server.id != id).toList();
    notifyListeners();
  }

  @override
  Future<void> moveServerBefore(
    String id,
    String? groupId,
    String? beforeId,
  ) async {
    if (presentationFor(id).groupId != groupId) {
      await moveServersToGroup({id}, groupId);
    }
    final oldIndex = items.indexWhere((server) => server.id == id);
    final remaining = items.where((server) => server.id != id).toList();
    await reorderServers(
      oldIndex,
      beforeId == null
          ? remaining.length
          : remaining.indexWhere((server) => server.id == beforeId),
    );
  }
}

McpServerConfig presentationServer(
  String id,
  String name, {
  bool enabled = true,
  McpTransportType transport = McpTransportType.http,
}) => McpServerConfig(
  id: id,
  name: name,
  enabled: enabled,
  transport: transport,
  tools: [
    for (var i = 0; i < 26; i++)
      McpToolConfig(enabled: i < 18, name: 'tool_$i'),
  ],
);

class McpPresentationHarness {
  McpPresentationHarness._(
    this.preferences,
    this.assistants,
    this.settings,
    this.mcp,
    this.assistantId,
  );

  final BusinessPreferences preferences;
  final AssistantProvider assistants;
  final SettingsProvider settings;
  final PresentationMcpProvider mcp;
  final String assistantId;

  static Future<McpPresentationHarness> create({int count = 3}) async {
    final preferences = createBusinessTestPreferences();
    await preferences.load();
    await preferences.setString(
      'mcp_servers_v1',
      jsonEncode([
        McpServerConfig(
          id: 'kelivo_fetch',
          name: '@kelivo/fetch',
          enabled: false,
          transport: McpTransportType.inmemory,
        ).toJson(),
      ]),
    );
    await preferences.setStringList('display_chat_tools_expanded_groups_v1', [
      'mcp',
    ]);
    final settings = SettingsProvider(preferences);
    final assistants = AssistantProvider(preferences: preferences);
    final mcp = PresentationMcpProvider(preferences: preferences);
    await Future.wait([settings.loaded, assistants.loaded, mcp.loaded]);
    final id = await assistants.addAssistant(name: 'Presentation');
    mcp.items = [
      for (var i = 0; i < count; i++)
        presentationServer(
          'server-$i',
          ['GitHub', 'Brave Search', 'Filesystem'][i % 3],
        ),
    ];
    await assistants.updateAssistant(
      assistants
          .getById(id)!
          .copyWith(
            mcpServerIds: [
              for (var i = 0; i < count; i++)
                if (i != 1) 'server-$i',
            ],
            localToolIds: ['get_time_info'],
          ),
    );
    return McpPresentationHarness._(preferences, assistants, settings, mcp, id);
  }

  Widget app(
    Widget home, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    ThemePalette palette = ThemePalettes.defaultPalette,
    Locale locale = const Locale('en'),
    String? fontFamily,
    Size? logicalSize,
  }) => MultiProvider(
    providers: [
      Provider<BusinessPreferences>.value(value: preferences),
      ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider<McpProvider>.value(value: mcp),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        fontFamily: fontFamily,
        colorScheme: brightness == Brightness.dark
            ? palette.dark
            : palette.light,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale), size: logicalSize),
        child: child!,
      ),
      home: home,
    ),
  );
}
