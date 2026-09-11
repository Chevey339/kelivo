import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('leading icon is size 20 with no decorated well', (tester) async {
    await tester.pumpWidget(
      wrap(const IosNavRow(icon: Lucide.Settings, label: 'Backup')),
    );

    final iconFinder = find.descendant(
      of: find.byType(IosNavRow),
      matching: find.byIcon(Lucide.Settings),
    );
    expect(tester.widget<Icon>(iconFinder).size, 20);

    final sizedBox = tester.widget<SizedBox>(
      find.ancestor(of: iconFinder, matching: find.byType(SizedBox)).first,
    );
    expect(sizedBox.width, 36);
    expect(sizedBox.child, isA<Icon>());
    expect(sizedBox.child, isNot(isA<DecoratedBox>()));
    expect(sizedBox.child, isNot(isA<Container>()));
  });

  testWidgets('divider indent is 54', (tester) async {
    await tester.pumpWidget(wrap(const IosRowDivider()));
    expect(tester.widget<Divider>(find.byType(Divider)).indent, 54);
  });

  testWidgets('destructive uses error colour on icon and label', (
    tester,
  ) async {
    late Color error;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            error = Theme.of(context).colorScheme.error;
            return const Scaffold(
              body: IosNavRow(
                icon: Lucide.Trash2,
                label: 'Delete',
                destructive: true,
              ),
            );
          },
        ),
      ),
    );

    expect(tester.widget<Icon>(find.byIcon(Lucide.Trash2)).color, error);
    expect(tester.widget<Text>(find.text('Delete')).style?.color, error);
  });

  testWidgets('chevron only when tappable and trailing is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const IosNavRow(icon: Lucide.Folder, label: 'Static')),
    );
    expect(find.byIcon(Lucide.ChevronRight), findsNothing);

    await tester.pumpWidget(
      wrap(IosNavRow(icon: Lucide.Folder, label: 'Open', onTap: () {})),
    );
    expect(find.byIcon(Lucide.ChevronRight), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        IosNavRow(
          icon: Lucide.Folder,
          label: 'Custom',
          onTap: () {},
          trailing: const Icon(Lucide.Check, size: 18),
        ),
      ),
    );
    expect(find.byIcon(Lucide.ChevronRight), findsNothing);
    expect(find.byIcon(Lucide.Check), findsOneWidget);
  });

  testWidgets('IosSwitchRow with icon shares the 36-wide slot with IosNavRow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const IosNavRow(icon: Lucide.Timer, label: 'Keep status'),
              IosSwitchRow(
                icon: Lucide.MapPin,
                label: 'Location',
                subtitle: 'Coarse updates while a task is running',
                value: true,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.byIcon(Lucide.Timer)).dx,
      tester.getTopLeft(find.byIcon(Lucide.MapPin)).dx,
    );
    expect(
      tester.getTopLeft(find.text('Keep status')).dx,
      tester.getTopLeft(find.text('Location')).dx,
    );
  });

  testWidgets('IosSwitchRow without icon aligns with IosNavRow without icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const IosNavRow(label: 'Name'),
              IosSwitchRow(
                label: 'Folders first',
                value: true,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('Folders first')).dx,
      tester.getTopLeft(find.text('Name')).dx,
    );
  });

  testWidgets('caption is 12px at 0.55 alpha under the subtitle', (
    tester,
  ) async {
    late Color onSurface;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            onSurface = Theme.of(context).colorScheme.onSurface;
            return const Scaffold(
              body: IosNavRow(
                icon: Lucide.Sparkles,
                label: 'PDF Tools',
                subtitle: 'Extract text',
                caption: 'used 3 times',
              ),
            );
          },
        ),
      ),
    );

    final caption = tester.widget<Text>(find.text('used 3 times'));
    expect(caption.style?.fontSize, 12);
    expect(caption.style?.color, onSurface.withValues(alpha: 0.55));
    expect(find.text('Extract text'), findsOneWidget);
  });

  testWidgets('IosNavRow subtitle can wrap when max lines is open', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SizedBox(
          width: 240,
          child: IosNavRow(
            icon: Lucide.Battery,
            label: 'Battery',
            subtitle: 'A long explanation that must wrap onto another line',
            subtitleMaxLines: null,
          ),
        ),
      ),
    );

    final subtitle = tester.widget<Text>(
      find.text('A long explanation that must wrap onto another line'),
    );
    expect(subtitle.maxLines, isNull);
    expect(subtitle.overflow, TextOverflow.visible);
  });
}
