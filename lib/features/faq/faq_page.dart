import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'faq_content.dart';

class FaqPage extends StatefulWidget {
  final String? initialEntryKey;

  const FaqPage({super.key, this.initialEntryKey});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          l10n.faqPageTitle,
          style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
      ),
      body: FaqContent(initialEntryKey: widget.initialEntryKey),
    );
  }
}
