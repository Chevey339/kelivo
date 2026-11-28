import 'package:flutter/material.dart';

import '../../../theme/surface_ladder.dart';

/// The file location and its actions share one toolbar across panel previews.
class SidePanelFileToolbar extends StatelessWidget {
  const SidePanelFileToolbar({
    super.key,
    required this.label,
    required this.path,
    required this.actions,
  });

  final String label;
  final String path;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: .5,
            color: SurfaceLadder.fromScheme(cs).hairline,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: path,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ...actions,
        ],
      ),
    );
  }
}
