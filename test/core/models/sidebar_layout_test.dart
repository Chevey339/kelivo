import 'package:Kelivo/core/models/sidebar_layout.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/business_test_harness.dart';

void main() {
  test(
    'the default and all four presets round-trip by visible block order',
    () {
      expect(
        SidebarLayout.fromPreferences(null, null).preset,
        SidebarPreset.current,
      );
      for (final preset in SidebarPreset.values) {
        final layout = preset.layout;
        final restored = SidebarLayout.fromPreferences(
          layout.style.name,
          layout.order.map((block) => block.id).toList(),
        );
        expect(restored.preset, preset);
      }
      final icons = SidebarLayout.fromPreferences('icons', [
        'entries',
        'search',
        'assistant',
        'convs',
        'user',
      ]);
      expect(icons.preset, SidebarPreset.current);
      expect(icons.visibleOrder, isNot(contains(SidebarBlock.entries)));
    },
  );

  test('fixed blocks move across the non-draggable conversation list', () {
    final layout = SidebarPreset.navigation.layout;
    final moved = layout.moveBlock(SidebarBlock.assistant, 3);
    expect(moved.preset, SidebarPreset.assistantAtBottom);
    expect(moved.isBelowConversations(SidebarBlock.assistant), isTrue);
    expect(moved.moveBlock(SidebarBlock.conversations, 0), same(moved));
    expect(moved.moveBlock(SidebarBlock.user, 0).preset, isNull);
  });

  test('entry order and all three visibility states are restored', () {
    const entries = {
      SidebarEntry.storage: SidebarVisibility.more,
      SidebarEntry.media: SidebarVisibility.show,
      SidebarEntry.history: SidebarVisibility.hidden,
      SidebarEntry.translate: SidebarVisibility.show,
      SidebarEntry.search: SidebarVisibility.more,
    };
    final restored = decodeSidebarEntries(
      encodeSidebarEntries(entries),
      defaultDesktopSidebarEntries,
    );
    expect(restored.keys, orderedEquals(entries.keys));
    expect(sidebarEntriesWithVisibility(restored, SidebarVisibility.more), [
      SidebarEntry.storage,
      SidebarEntry.search,
    ]);
    expect(sidebarEntriesWithVisibility(restored, SidebarVisibility.hidden), [
      SidebarEntry.history,
    ]);
    expect(sidebarEntriesWithVisibility(restored, SidebarVisibility.show), [
      SidebarEntry.media,
      SidebarEntry.translate,
    ]);
  });

  test('preset changes retain visibility and preferences reload', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final harness = await createBusinessTestHarness();
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    expect(settings.mobileSidebarLayout.preset, SidebarPreset.current);
    expect(settings.hideSidebarSingleAssistant, isFalse);
    expect(settings.showSidebarCustomizeInMore, isTrue);

    const entries = {
      SidebarEntry.translate: SidebarVisibility.more,
      SidebarEntry.media: SidebarVisibility.show,
      SidebarEntry.history: SidebarVisibility.hidden,
    };
    await settings.setMobileSidebarEntries(entries);
    await settings.setMobileSidebarLayout(SidebarPreset.allAtTop.layout);
    await settings.setHideSidebarSingleAssistant(true);
    await settings.setShowSidebarCustomizeInMore(false);
    settings.dispose();

    final reopened = SettingsProvider(harness.preferences);
    addTearDown(reopened.dispose);
    await reopened.loaded;
    expect(reopened.mobileSidebarLayout.preset, SidebarPreset.allAtTop);
    expect(reopened.mobileSidebarEntries, entries);
    expect(reopened.mobileSidebarEntries.keys, orderedEquals(entries.keys));
    expect(reopened.hideSidebarSingleAssistant, isTrue);
    expect(reopened.showSidebarCustomizeInMore, isFalse);
  });
}
