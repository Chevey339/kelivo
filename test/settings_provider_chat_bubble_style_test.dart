import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/theme/chat_bubble_style.dart';

import 'support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bubble style overrides default to empty', () async {
    final harness = await createBusinessTestHarness(initial: {});
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;

    expect(settings.chatBubbleStyleOverrides, const ChatBubbleStyleOverrides());
    expect(settings.chatBubbleStyleOverrides.isDefault, isTrue);
    expect(
      settings.userChatBubbleStyleOverrides,
      settings.assistantChatBubbleStyleOverrides,
    );
    expect(
      settings.chatBubbleStyleOverridesFor(isUser: true),
      settings.chatBubbleStyleOverridesFor(isUser: false),
    );
  });

  test(
    'user-only overrides leave assistant unchanged and survive reload',
    () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;

      const user = ChatBubbleStyleOverrides(
        textArgbLight: 0xFFAA2200,
        cornerRadius: 20,
      );
      await settings.setChatBubbleStyleOverridesForRole(
        isUser: true,
        value: user,
      );

      expect(
        settings.assistantChatBubbleStyleOverrides,
        const ChatBubbleStyleOverrides(),
      );
      expect(settings.userChatBubbleStyleOverrides, user);
      expect(settings.chatBubbleStyleOverridesFor(isUser: true), user);
      expect(
        settings.chatBubbleStyleOverridesFor(isUser: false),
        const ChatBubbleStyleOverrides(),
      );
      expect(
        harness.preferences.getString('chat_bubble_style_overrides_user_v1'),
        jsonEncode(user.toJson()),
      );

      final reloaded = SettingsProvider(harness.preferences);
      await reloaded.loaded;
      expect(
        reloaded.assistantChatBubbleStyleOverrides,
        const ChatBubbleStyleOverrides(),
      );
      expect(reloaded.userChatBubbleStyleOverrides, user);
    },
  );

  test(
    'first assistant role write snapshots the previous assistant value onto user',
    () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;

      const shared = ChatBubbleStyleOverrides(
        backgroundArgbLight: 0xFF112233,
        cornerRadius: 8,
      );
      await settings.setChatBubbleStyleOverrides(shared);
      expect(settings.userChatBubbleStyleOverrides, shared);
      expect(
        harness.preferences.getString('chat_bubble_style_overrides_user_v1'),
        isNull,
      );

      const assistantNext = ChatBubbleStyleOverrides(cornerRadius: 2);
      await settings.setChatBubbleStyleOverridesForRole(
        isUser: false,
        value: assistantNext,
      );

      expect(settings.assistantChatBubbleStyleOverrides, assistantNext);
      expect(settings.userChatBubbleStyleOverrides, shared);
      expect(
        harness.preferences.getString('chat_bubble_style_overrides_user_v1'),
        jsonEncode(shared.toJson()),
      );

      final reloaded = SettingsProvider(harness.preferences);
      await reloaded.loaded;
      expect(reloaded.assistantChatBubbleStyleOverrides, assistantNext);
      expect(reloaded.userChatBubbleStyleOverrides, shared);
    },
  );

  test(
    'overlapping first assistant role writes persist the latest value',
    () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;

      const shared = ChatBubbleStyleOverrides(
        backgroundArgbLight: 0xFF112233,
        cornerRadius: 8,
      );
      await settings.setChatBubbleStyleOverrides(shared);
      expect(
        harness.preferences.getString('chat_bubble_style_overrides_user_v1'),
        isNull,
      );

      const assistantA = ChatBubbleStyleOverrides(cornerRadius: 2);
      const assistantB = ChatBubbleStyleOverrides(cornerRadius: 4);
      final first = settings.setChatBubbleStyleOverridesForRole(
        isUser: false,
        value: assistantA,
      );
      final second = settings.setChatBubbleStyleOverridesForRole(
        isUser: false,
        value: assistantB,
      );
      await first;
      await second;

      expect(settings.assistantChatBubbleStyleOverrides, assistantB);
      expect(settings.userChatBubbleStyleOverrides, shared);
      expect(
        harness.preferences.getString('chat_bubble_style_overrides_v1'),
        jsonEncode(assistantB.toJson()),
      );
      expect(
        harness.preferences.getString('chat_bubble_style_overrides_user_v1'),
        jsonEncode(shared.toJson()),
      );

      final reloaded = SettingsProvider(harness.preferences);
      await reloaded.loaded;
      expect(reloaded.assistantChatBubbleStyleOverrides, assistantB);
      expect(reloaded.userChatBubbleStyleOverrides, shared);
    },
  );

  test(
    'reset clears a user-only split even when assistant is already default',
    () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      await settings.setChatBubbleStyleOverridesForRole(
        isUser: true,
        value: const ChatBubbleStyleOverrides(cornerRadius: 20),
      );

      await settings.setChatBubbleStyleOverrides(
        const ChatBubbleStyleOverrides(),
      );

      expect(settings.assistantChatBubbleStyleOverrides.isDefault, isTrue);
      expect(settings.userChatBubbleStyleOverrides.isDefault, isTrue);
      expect(
        harness.preferences.getString('chat_bubble_style_overrides_user_v1'),
        isNull,
      );
    },
  );

  test('persists and reloads bubble style overrides', () async {
    final harness = await createBusinessTestHarness(initial: {});
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;

    const next = ChatBubbleStyleOverrides(
      backgroundArgbLight: 0xFF112233,
      frostedOpacity: 0.4,
      blurSigma: 22,
      cornerRadius: 8,
    );
    await settings.setChatBubbleStyleOverrides(next);

    expect(settings.chatBubbleStyleOverrides, next);
    expect(
      harness.preferences.getString('chat_bubble_style_overrides_v1'),
      jsonEncode(next.toJson()),
    );

    final reloaded = SettingsProvider(harness.preferences);
    await reloaded.loaded;
    expect(reloaded.chatBubbleStyleOverrides, next);
  });

  test('reset persists an empty override object', () async {
    final harness = await createBusinessTestHarness(initial: {});
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    await settings.setChatBubbleStyleOverrides(
      const ChatBubbleStyleOverrides(blurSigma: 9),
    );
    await settings.setChatBubbleStyleOverrides(
      const ChatBubbleStyleOverrides(),
    );

    expect(settings.chatBubbleStyleOverrides.isDefault, isTrue);
    expect(
      harness.preferences.getString('chat_bubble_style_overrides_v1'),
      '{}',
    );
  });

  test('backup registry classifies the overrides key as a preference', () {
    expect(
      BusinessKeyRegistry.classify('chat_bubble_style_overrides_v1'),
      BusinessKeyDisposition.preference,
    );
    expect(
      BusinessKeyRegistry.preferenceKeys,
      contains('chat_bubble_style_overrides_v1'),
    );
    expect(
      BusinessKeyRegistry.classify('chat_bubble_style_overrides_user_v1'),
      BusinessKeyDisposition.preference,
    );
    expect(
      BusinessKeyRegistry.preferenceKeys,
      contains('chat_bubble_style_overrides_user_v1'),
    );
  });
}
