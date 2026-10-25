import 'package:flutter/material.dart';

/// The desktop keeps source editing visible while preview and syntax share tabs.
class DesktopMarkdownPlaygroundLayout extends StatelessWidget {
  const DesktopMarkdownPlaygroundLayout({
    super.key,
    required this.editor,
    required this.preview,
    required this.ast,
    required this.selection,
    required this.tabs,
    required this.tabLabels,
  });
  final Widget editor, preview, ast, selection;
  final TabController tabs;
  final List<String> tabLabels;
  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('markdown-playground-desktop'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: editor),
      const SizedBox(width: 16),
      Expanded(
        flex: 2,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              TabBar(
                controller: tabs,
                tabs: [for (final label in tabLabels) Tab(text: label)],
              ),
              Expanded(
                child: TabBarView(controller: tabs, children: [preview, ast]),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: (constraints.maxHeight * .25).clamp(0, 136),
                child: selection,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Small windows switch between the three panes instead of compressing them.
class MobileMarkdownPlaygroundLayout extends StatelessWidget {
  const MobileMarkdownPlaygroundLayout({
    super.key,
    required this.editor,
    required this.preview,
    required this.ast,
    required this.selection,
    required this.tabs,
    required this.tabLabels,
  });
  final Widget editor, preview, ast, selection;
  final TabController tabs;
  final List<String> tabLabels;
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('markdown-playground-mobile'),
    children: [
      TabBar(
        controller: tabs,
        onTap: (_) => FocusScope.of(context).unfocus(),
        tabs: [for (final label in tabLabels) Tab(text: label)],
      ),
      Expanded(
        child: TabBarView(
          controller: tabs,
          children: [
            editor,
            LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  Expanded(child: preview),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: (constraints.maxHeight * .3).clamp(0, 116),
                    child: selection,
                  ),
                ],
              ),
            ),
            ast,
          ],
        ),
      ),
    ],
  );
}
