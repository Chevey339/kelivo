import 'package:flutter/material.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/provider_url.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../utils/provider_url_editor.dart';
import 'provider_input_row.dart';

class ProviderBaseUrlField extends StatefulWidget {
  const ProviderBaseUrlField({
    super.key,
    required this.editor,
    required this.config,
    required this.defaultBaseUrl,
    required this.onCommit,
    this.restoreDefault = false,
    this.enabled = true,
    this.desktop = false,
    this.focusNode,
    this.label,
    this.onDetachedUndo,
  });
  final ProviderUrlEditor editor;
  final ProviderConfig config;
  final String defaultBaseUrl;
  final ValueChanged<NormalizeResult> onCommit;
  final bool restoreDefault;
  final bool enabled;
  final bool desktop;
  final FocusNode? focusNode;
  final String? label;
  final void Function(String bareUrl, String replacedUrl)? onDetachedUndo;

  @override
  State<ProviderBaseUrlField> createState() => ProviderBaseUrlFieldState();
}

class ProviderBaseUrlFieldState extends State<ProviderBaseUrlField> {
  late final FocusNode _ownFocus = FocusNode();
  FocusNode get _focus => widget.focusNode ?? _ownFocus;
  ProviderKind get _kind => ProviderConfig.classify(
    widget.config.id,
    explicitType: widget.config.providerType,
  );

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(ProviderBaseUrlField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocus).removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  void _onFocus() {
    if (!_focus.hasFocus && mounted && widget.enabled) commit();
  }

  bool commit() {
    final editor = widget.editor;
    final kind = _kind;
    final detachedUndo = widget.onDetachedUndo;
    final bare = normalizeBaseUrl(
      editor.controller.text,
      kind,
      allowAutoVersion: false,
    ).value;
    final result = editor.commit(kind);
    if (result.error != null) return false;
    widget.onCommit(result);
    if (result.notes.contains(NormalizeNote.addedVersion)) {
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.providerAutoVersionAdded(providerUrlVersion(_kind)),
        actionLabel: l10n.providerUndo,
        onAction: () {
          if (!mounted || !identical(widget.editor, editor)) {
            detachedUndo?.call(bare, result.value);
            return;
          }
          if (editor.controller.text != result.value) return;
          final undone = editor.undoAutoVersion(kind);
          if (undone != null) widget.onCommit(undone);
        },
      );
    }
    return true;
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: widget.editor,
      builder: (context, _) {
        final result = widget.editor.preview(_kind);
        final error = widget.editor.error(_kind);
        final config = widget.config.copyWith(
          baseUrl: result.value,
          chatPath: _kind == ProviderKind.openai
              ? result.movedPath ?? widget.config.chatPath
              : null,
        );
        final version = providerUrlVersion(_kind);
        final messages = <String>[
          if (result.error == null &&
              result.notes.contains(NormalizeNote.addedVersion))
            l10n.providerDetailPageUrlWillAppendVersion(version),
          if (widget.editor.notes.contains(NormalizeNote.addedVersion))
            l10n.providerDetailPageUrlAppendedVersion(version),
          if (widget.editor.notes.contains(NormalizeNote.trimmedSlash))
            l10n.providerDetailPageUrlTrimmedSlash,
          if (_kind == ProviderKind.openai && widget.editor.movedPath != null)
            l10n.providerDetailPageUrlMovedPath(widget.editor.movedPath!),
        ];
        return ProviderInputRow(
          label: widget.label ?? l10n.providerDetailPageApiBaseUrlLabel,
          controller: widget.editor.controller,
          focusNode: _focus,
          hint: l10n.providerDetailPageBaseUrlExample(widget.defaultBaseUrl),
          enabled: widget.enabled,
          desktop: widget.desktop,
          keyboardType: TextInputType.url,
          trailing: widget.restoreDefault
              ? TrailingKind.reset
              : TrailingKind.clear,
          onTrailingTap: () {
            widget.editor.controller.text = widget.defaultBaseUrl;
            commit();
          },
          onSubmitted: (_) {
            commit();
            _focus.unfocus();
          },
          errorText: switch (error) {
            UrlError.empty => l10n.providerDetailPageUrlEmptyError,
            UrlError.invalid => l10n.providerDetailPageUrlInvalidError,
            null => null,
          },
          helperRich: result.error != null
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProviderRequestUrlPreview(
                      config: config,
                      base: result.notes.contains(NormalizeNote.addedVersion)
                          ? normalizeBaseUrl(
                              widget.editor.controller.text,
                              _kind,
                              allowAutoVersion: false,
                            ).value
                          : result.value,
                    ),
                    for (final message in messages)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class ProviderRequestUrlPreview extends StatelessWidget {
  const ProviderRequestUrlPreview({super.key, required this.config, this.base});
  final ProviderConfig config;
  final String? base;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = resolveRequestUrl(config);
    final source = base ?? config.baseUrl;
    var split = 0;
    while (split < source.length &&
        split < url.length &&
        source[split] == url[split]) {
      split++;
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text:
                '${AppLocalizations.of(context)!.providerDetailPageRequestUrlLabel} ',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5)),
          ),
          TextSpan(
            text: url.substring(0, split),
            style: TextStyle(
              fontFamily: 'monospace',
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          TextSpan(
            text: url.substring(split),
            style: TextStyle(
              fontFamily: 'monospace',
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 12, height: 1.4),
    );
  }
}
