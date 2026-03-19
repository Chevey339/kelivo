import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../l10n/app_localizations.dart';

class GoogleFontsPickerPage extends StatefulWidget {
  const GoogleFontsPickerPage({super.key, required this.title});
  final String title;
  @override
  State<GoogleFontsPickerPage> createState() => _GoogleFontsPickerPageState();
}

class _GoogleFontsPickerPageState extends State<GoogleFontsPickerPage> {
  late final TextEditingController _filterCtrl;

  @override
  void initState() {
    super.initState();
    _filterCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final allFonts = GoogleFonts.asMap().keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _filterCtrl,
              decoration: InputDecoration(
                hintText: l10n.fontPickerFilterHint,
                isDense: true,
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white10
                    : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.28),
                    width: 0.8,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered(allFonts).length,
              itemBuilder: (context, i) {
                final fam = _filtered(allFonts)[i];
                return ListTile(
                  title: Text(fam),
                  trailing: Text(
                    'Aa字',
                    style: GoogleFonts.getFont(fam, fontSize: 18),
                  ),
                  onTap: () => Navigator.of(context).pop(fam),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<String> _filtered(List<String> all) {
    final q = _filterCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((e) => e.toLowerCase().contains(q)).toList();
  }
}
