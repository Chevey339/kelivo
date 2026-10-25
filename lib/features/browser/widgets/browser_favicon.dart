import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/services/browser/browser_service.dart';

/// Displays only icons obtained by the existing browser session. Saved pages
/// never cause external favicon requests just because a list becomes visible.
class BrowserFavicon extends StatelessWidget {
  const BrowserFavicon({
    super.key,
    required this.url,
    this.service,
    this.size = 20,
  });
  final String url;
  final BrowserService? service;
  final double size;

  @override
  Widget build(BuildContext context) {
    final browser = service ?? BrowserService.instance;
    Widget fallback() => Icon(
      url.isEmpty || url == 'about:blank'
          ? LucideIcons.compass
          : LucideIcons.globe,
      size: size,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ListenableBuilder(
          listenable: browser,
          builder: (context, _) {
            final bytes = browser.faviconForUrl(url);
            if (bytes == null) return fallback();
            return Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: false,
              errorBuilder: (_, __, ___) => fallback(),
            );
          },
        ),
      ),
    );
  }
}
