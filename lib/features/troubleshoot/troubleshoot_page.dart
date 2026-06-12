import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'troubleshoot_content.dart';

class TroubleshootPage extends StatefulWidget {
  final String? initialEntryKey;

  const TroubleshootPage({super.key, this.initialEntryKey});

  @override
  State<TroubleshootPage> createState() => _TroubleshootPageState();
}

class _TroubleshootPageState extends State<TroubleshootPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          l10n.troubleshootPageTitle,
          style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
      ),
      body: TroubleshootContent(initialEntryKey: widget.initialEntryKey),
    );
  }
}
