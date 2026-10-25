import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../widgets/browser_text_field.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../models/browser_models.dart';
import '../browser_management_route.dart';
import '../widgets/browser_surface_controls.dart';
import 'browser_management_page.dart';

typedef BrowserBookmarkEdit = ({String title, String url});

/// Mobile editing is a normal full-page route; desktop retains a compact form
/// dialog. [favicon] is a presentation slot for the browser's cached site icon.
Future<BrowserBookmarkEdit?> showBrowserBookmarkEditor(
  BuildContext context, {
  required BrowserBookmark bookmark,
  Widget? favicon,
}) {
  final desktop =
      ResponsiveHelper.isDesktop(context) ||
      switch (Theme.of(context).platform) {
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux => true,
        _ => false,
      };
  final editor = BrowserBookmarkEditor(
    bookmark: bookmark,
    favicon: favicon,
    fullPage: !desktop,
  );
  if (desktop) {
    return showBrowserDialog<BrowserBookmarkEdit>(
      context,
      maxWidth: 460,
      child: editor,
    );
  }
  final navigator = Navigator.of(context);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  return navigator.push<BrowserBookmarkEdit>(
    browserManagementRoute(
      context: context,
      builder: (_) => themes.wrap(editor),
    ),
  );
}

class BrowserBookmarkEditor extends StatefulWidget {
  const BrowserBookmarkEditor({
    super.key,
    required this.bookmark,
    this.favicon,
    this.fullPage = true,
  });
  final BrowserBookmark bookmark;
  final Widget? favicon;
  final bool fullPage;
  @override
  State<BrowserBookmarkEditor> createState() => _BrowserBookmarkEditorState();
}

class _BrowserBookmarkEditorState extends State<BrowserBookmarkEditor> {
  late final _title = TextEditingController(text: widget.bookmark.title);
  late final _url = TextEditingController(text: widget.bookmark.url);
  bool _invalid = false;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  void _save() {
    final value = _url.text.trim();
    final parsed = Uri.tryParse(value);
    if (parsed == null ||
        !const {'http', 'https'}.contains(parsed.scheme) ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop<BrowserBookmarkEdit>((
      title: _title.text.trim().isEmpty ? parsed.host : _title.text.trim(),
      url: value,
    ));
  }

  Widget _saveButton(BuildContext context, {bool mobile = false}) =>
      BrowserTextButton(
        onPressed: _save,
        filled: !mobile,
        backgroundColor: mobile ? Theme.of(context).colorScheme.primary : null,
        foregroundColor: mobile
            ? Theme.of(context).colorScheme.onPrimary
            : null,
        child: Text(
          AppLocalizations.of(context)!.browserSave,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );

  Widget _header(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final titleStyle = DefaultTextStyle.of(
      context,
    ).style.merge(const TextStyle(fontSize: 17, fontWeight: FontWeight.w600));
    // Let the actual localized button lay itself out. Measuring just its font
    // size misses inherited letter spacing and font fallback, which can leave
    // the save label with less width than even its ellipsis needs.
    final height = math.max(
      48.0,
      MediaQuery.textScalerOf(context).scale(17) * (titleStyle.height ?? 1.2) +
          24,
    );
    return SizedBox(
      height: height,
      child: CustomMultiChildLayout(
        delegate: _BookmarkHeaderLayout(Directionality.of(context)),
        children: [
          LayoutId(
            id: _BookmarkHeaderSlot.close,
            child: BrowserSurfaceIconButton(
              label: l.browserCancel,
              icon: LucideIcons.x,
              size: 48,
              iconSize: 23,
              surface: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          LayoutId(
            id: _BookmarkHeaderSlot.title,
            child: Text(
              l.browserEditBookmark,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
          LayoutId(
            id: _BookmarkHeaderSlot.save,
            child: _saveButton(context, mobile: true),
          ),
        ],
      ),
    );
  }

  Widget _mobileField(BuildContext context, {required bool url}) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final appTextStyle = Theme.of(context).textTheme.bodyMedium!;
    final label = url ? l.browserBookmarkUrl : l.browserBookmarkTitle;
    return Semantics(
      label: label,
      textField: true,
      child: BrowserTextField(
        key: ValueKey(
          url ? 'browserBookmarkUrlField' : 'browserBookmarkTitleField',
        ),
        controller: url ? _url : _title,
        placeholder: label,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 2),
        style: TextStyle(
          fontFamily: appTextStyle.fontFamily,
          fontFamilyFallback: appTextStyle.fontFamilyFallback,
          fontSize: url ? 15 : 17,
          color: url ? colors.onSurfaceVariant : colors.onSurface,
        ),
        placeholderStyle: TextStyle(
          fontSize: url ? 15 : 17,
          color: colors.onSurfaceVariant,
        ),
        keyboardType: url ? TextInputType.url : TextInputType.text,
        textInputAction: url ? TextInputAction.done : TextInputAction.next,
        autocorrect: !url,
        enableSuggestions: !url,
        onChanged: url && _invalid
            ? (_) => setState(() => _invalid = false)
            : null,
        onSubmitted: url
            ? (_) => _save()
            : (_) => FocusScope.of(context).nextFocus(),
      ),
    );
  }

  Widget _form(BuildContext context) => BrowserSurfaceGroup(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: SizedBox.square(
                key: const ValueKey('browserBookmarkFavicon'),
                dimension: 40,
                child:
                    widget.favicon ??
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.globe, size: 25),
                    ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [
                  _mobileField(context, url: false),
                  Divider(
                    height: .5,
                    thickness: .5,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .09),
                  ),
                  _mobileField(context, url: true),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _error(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    child: Semantics(
      liveRegion: true,
      child: Text(
        AppLocalizations.of(context)!.browserInvalidUrl,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (!widget.fullPage) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrowserDialogHeader(title: l.browserEditBookmark),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                BrowserSurfaceField(
                  label: l.browserBookmarkTitle,
                  controller: _title,
                ),
                const SizedBox(height: 16),
                BrowserSurfaceField(
                  label: l.browserBookmarkUrl,
                  controller: _url,
                  keyboardType: TextInputType.url,
                  onSubmitted: (_) => _save(),
                ),
              ],
            ),
          ),
          if (_invalid) _error(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                BrowserTextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.browserCancel),
                ),
                _saveButton(context),
              ],
            ),
          ),
        ],
      );
    }
    return BrowserManagementPage(
      title: l.browserEditBookmark,
      showHeader: false,
      // Build below the management page's Material/DefaultTextStyle boundary.
      // Cupertino routes otherwise supply the diagnostic red/underlined style
      // to _header before the page has installed its actual text theme.
      child: Builder(
        builder: (pageContext) => SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
                child: _header(pageContext),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  children: [
                    _form(pageContext),
                    if (_invalid) _error(pageContext),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _BookmarkHeaderSlot { close, title, save }

/// Measure both controls before laying out the title. Unlike NavigationToolbar,
/// this always reserves symmetric space so a long title cannot drift off center.
class _BookmarkHeaderLayout extends MultiChildLayoutDelegate {
  _BookmarkHeaderLayout(this.direction);
  final TextDirection direction;

  @override
  void performLayout(Size size) {
    final close = layoutChild(
      _BookmarkHeaderSlot.close,
      BoxConstraints.loose(size),
    );
    final save = layoutChild(
      _BookmarkHeaderSlot.save,
      BoxConstraints.loose(
        Size(math.max(0, size.width - close.width - 16), size.height),
      ),
    );
    final side = math.max(close.width, save.width) + 8;
    final title = layoutChild(
      _BookmarkHeaderSlot.title,
      BoxConstraints.loose(
        Size(math.max(0, size.width - side * 2), size.height),
      ),
    );
    positionChild(
      _BookmarkHeaderSlot.close,
      Offset(
        direction == TextDirection.ltr ? 0 : size.width - close.width,
        (size.height - close.height) / 2,
      ),
    );
    positionChild(
      _BookmarkHeaderSlot.save,
      Offset(
        direction == TextDirection.ltr ? size.width - save.width : 0,
        (size.height - save.height) / 2,
      ),
    );
    positionChild(
      _BookmarkHeaderSlot.title,
      Offset((size.width - title.width) / 2, (size.height - title.height) / 2),
    );
  }

  @override
  bool shouldRelayout(_BookmarkHeaderLayout oldDelegate) =>
      direction != oldDelegate.direction;
}
