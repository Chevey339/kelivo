import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/features/chat/widgets/frosted/chat_frosted_backdrop.dart';
import 'business_test_harness.dart';

/// Stable wallpaper context shared by visual and performance probes. No image
/// network requests or gradient animation. Uses the real background publisher.
class MarkdownWallpaperTestHost extends StatefulWidget {
  const MarkdownWallpaperTestHost({super.key, required this.child});
  final Widget child;
  @override
  State<MarkdownWallpaperTestHost> createState() => _WallpaperHostState();
}

class _WallpaperHostState extends State<MarkdownWallpaperTestHost> {
  final _assistants = _WallpaperAssistants();
  @override
  void dispose() {
    _assistants.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider<AssistantProvider>.value(
        value: _assistants,
        child: ChatFrostedBackdrop(
          backdrop: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xff782633),
                  Color(0xffd2c6b1),
                  Color(0xff172c37),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          child: widget.child,
        ),
      );
}

class _WallpaperAssistants extends AssistantProvider {
  _WallpaperAssistants() : super(preferences: createBusinessTestPreferences());
  final _wallpaper = Assistant(
    id: 'wallpaper-fixture',
    name: 'Wallpaper',
    background: 'https://fixture.invalid/wallpaper.png',
  );
  @override
  Assistant get currentAssistant => _wallpaper;
}

Widget markdownBenchmarkBackdrop(Widget child) =>
    const bool.fromEnvironment('MARKSTREAM_BENCH_WALLPAPER')
    ? MarkdownWallpaperTestHost(child: child)
    : child;
