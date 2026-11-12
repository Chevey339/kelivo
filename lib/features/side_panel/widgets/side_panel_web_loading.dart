import 'package:flutter/material.dart';
import '../../../theme/surface_ladder.dart';

class SidePanelWebLoading extends StatelessWidget {
  const SidePanelWebLoading({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fill = SurfaceLadder.fromScheme(cs).surfaceFill;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                for (final width in [.45, .8, .7, .9, .65])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: FractionallySizedBox(
                      widthFactor: width,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
