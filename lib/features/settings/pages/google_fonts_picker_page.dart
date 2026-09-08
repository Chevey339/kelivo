import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/fonts/google_fonts_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/ios_form_text_field.dart';

Future<void> showGoogleFontsPicker(
  BuildContext context, {
  required bool forCode,
}) async {
  final settings = context.read<SettingsProvider>();
  final picker = GoogleFontsPickerPage(
    onApply: (font) => forCode
        ? settings.setCodeFontFromLocal(
            path: font.file.path,
            licenseText: font.license,
          )
        : settings.setAppFontFromLocal(
            path: font.file.path,
            licenseText: font.license,
          ),
  );
  if (ResponsiveHelper.isDesktop(context)) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(width: 640, height: 720, child: picker),
      ),
    );
  } else {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => picker));
  }
}

class GoogleFontsPickerPage extends StatefulWidget {
  const GoogleFontsPickerPage({super.key, required this.onApply, this.service});

  final Future<bool> Function(DownloadedGoogleFont font) onApply;
  final GoogleFontsService? service;

  @override
  State<GoogleFontsPickerPage> createState() => _GoogleFontsPickerPageState();
}

class _GoogleFontsPickerPageState extends State<GoogleFontsPickerPage> {
  late final GoogleFontsService _service =
      widget.service ?? GoogleFontsService();
  // Flutter retains registered fonts for the engine lifetime. Reuse completed
  // registrations across picker instances, and share concurrent loads.
  static final _previewFamilies = <Uri, String>{};
  static final _previewLoads = <Uri, Future<String>>{};
  static int _nextPreviewFontId = 0;

  static Future<String> _loadPreviewFont(
    GoogleFontEntry font,
    DownloadedGoogleFont download,
  ) async {
    final cached = _previewFamilies[font.url];
    if (cached != null) return cached;
    return _previewLoads.putIfAbsent(font.url, () async {
      try {
        final family = 'kelivo_font_preview_${_nextPreviewFontId++}';
        final bytes = await download.file.readAsBytes();
        final loader = FontLoader(family)
          ..addFont(Future.value(bytes.buffer.asByteData()));
        await loader.load();
        _previewFamilies[font.url] = family;
        return family;
      } finally {
        _previewLoads.remove(font.url);
      }
    });
  }

  final _search = TextEditingController();
  final _scrollController = ScrollController();
  List<GoogleFontEntry> _fonts = [];
  bool _loading = true;
  bool _downloading = false;
  bool _applying = false;
  bool _failed = false;
  double? _progress;
  GoogleFontEntry? _selected;
  DownloadedGoogleFont? _download;
  String? _previewFamily;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _service.close();
    _search.dispose();
    _scrollController.dispose();
    final download = _download;
    if (download != null) unawaited(download.dispose());
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final fonts = await _service.loadCatalog(refresh: refresh);
      if (mounted) setState(() => _fonts = fonts);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(GoogleFontEntry font) async {
    if (_downloading || _applying) return;
    if (_selected?.url == font.url && _download != null) return;
    FocusScope.of(context).unfocus();
    final previous = _download;
    setState(() {
      _selected = font;
      _download = null;
      _previewFamily = null;
      _downloading = true;
      _progress = null;
      _failed = false;
    });
    if (_scrollController.hasClients) {
      unawaited(
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    }
    DownloadedGoogleFont? pending;
    try {
      if (previous != null) await previous.dispose();
      pending = await _service.download(
        font,
        onProgress: (received, total) {
          if (!mounted) return;
          final progress = total != null && total > 0 ? received / total : null;
          // Rebuild at most once per percent of a large font download.
          if (progress != null &&
              (_progress == null || progress - _progress! >= 0.01)) {
            setState(() => _progress = progress);
          }
        },
      );
      if (!mounted) return;
      final family = await _loadPreviewFont(font, pending);
      if (!mounted) return;
      setState(() {
        _download = pending;
        _previewFamily = family;
      });
      pending = null;
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (pending != null) await pending.dispose();
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _apply() async {
    final download = _download;
    if (download == null) return;
    setState(() {
      _applying = true;
      _failed = false;
    });
    var success = false;
    try {
      success = await widget.onApply(download);
    } catch (_) {
      // Keep the preview and allow retrying a failed import.
    }
    if (!mounted) return;
    setState(() {
      _applying = false;
      _failed = !success;
    });
    if (success) {
      // Let PopScope rebuild before requesting the successful route pop.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final query = _search.text.trim().toLowerCase();
    final fonts = _fonts
        .where(
          (font) =>
              font.family.toLowerCase().contains(query) ||
              font.subsets.any((subset) => subset.contains(query)),
        )
        .toList();
    return PopScope(
      canPop: !_applying,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.googleFontsTitle),
          leading: IconButton(
            tooltip: l10n.statsPageClose,
            icon: const Icon(Lucide.X),
            onPressed: _applying ? null : () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              tooltip: l10n.googleFontsRefresh,
              icon: const Icon(Lucide.RefreshCw),
              onPressed: _loading || _downloading || _applying
                  ? null
                  : () => _load(refresh: true),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: CustomScrollView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (!keyboardVisible)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          l10n.googleFontsHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    IosFormTextField(
                      label: l10n.settingsPageSearch,
                      controller: _search,
                      hintText: l10n.googleFontsSearchHint,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_failed)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          l10n.googleFontsFailed,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_selected != null && !keyboardVisible)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _selected!.family,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            if (_downloading) ...[
                              LinearProgressIndicator(value: _progress),
                              const SizedBox(height: 8),
                              Text(l10n.googleFontsDownloading),
                            ] else if (_previewFamily != null) ...[
                              Text(
                                l10n.googleFontsPreview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: _previewFamily,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: _applying
                                        ? null
                                        : () => showDialog<void>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text(_selected!.family),
                                              content: SingleChildScrollView(
                                                child: SelectableText(
                                                  _download!.license,
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    context,
                                                  ).pop(),
                                                  child: Text(
                                                    l10n.statsPageClose,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                    child: Text(l10n.googleFontsLicense),
                                  ),
                                  FilledButton(
                                    onPressed: _applying ? null : _apply,
                                    child: Text(l10n.statsPageCustomRangeApply),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_loading || fonts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : _failed
                        ? TextButton(
                            onPressed: () => _load(refresh: true),
                            child: Text(l10n.googleFontsRefresh),
                          )
                        : Text(l10n.googleFontsNoResults),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: fonts.length,
                  itemBuilder: (context, index) {
                    final font = fonts[index];
                    return ListTile(
                      title: Text(font.family),
                      selected: font.url == _selected?.url,
                      trailing: const Icon(Lucide.Download, size: 18),
                      onTap: _downloading || _applying
                          ? null
                          : () => _select(font),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
