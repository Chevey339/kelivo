part of '../pages/assistant_settings_edit_page.dart';

class AssistantGradientSettings extends StatefulWidget {
  const AssistantGradientSettings({super.key, required this.assistant});
  final Assistant assistant;

  @override
  State<AssistantGradientSettings> createState() =>
      _AssistantGradientSettingsState();
}

class _AssistantGradientSettingsState extends State<AssistantGradientSettings> {
  late double _x = widget.assistant.gradientBackgroundOffsetX;
  late double _y = widget.assistant.gradientBackgroundOffsetY;
  late double _previewFrame = widget.assistant.gradientBackgroundPhase;

  @override
  void didUpdateWidget(AssistantGradientSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assistant.id != widget.assistant.id ||
        oldWidget.assistant.gradientBackgroundOffsetX !=
            widget.assistant.gradientBackgroundOffsetX ||
        oldWidget.assistant.gradientBackgroundOffsetY !=
            widget.assistant.gradientBackgroundOffsetY) {
      _x = widget.assistant.gradientBackgroundOffsetX;
      _y = widget.assistant.gradientBackgroundOffsetY;
    }
  }

  Future<void> _savePosition() async {
    final provider = context.read<AssistantProvider>();
    final current = provider.getById(widget.assistant.id);
    if (current == null) return;
    await provider.updateAssistant(
      current.copyWith(
        gradientBackgroundOffsetX: _x,
        gradientBackgroundOffsetY: _y,
      ),
    );
  }

  Future<void> _setStatic(bool value) async {
    final provider = context.read<AssistantProvider>();
    final current = provider.getById(widget.assistant.id);
    if (current == null) return;
    // Persist the visible frame. Both the preview and the chat render this
    // exact timeline position after the animation stops and after a restart.
    await provider.updateAssistant(
      current.copyWith(
        gradientBackgroundAnimated: !value,
        gradientBackgroundPhase: _previewFrame,
      ),
    );
  }

  Future<void> _nextFrame() async {
    const frames = [2.0, 4.0, 7.0, 9.5, 12.0, 16.0];
    final provider = context.read<AssistantProvider>();
    final current = provider.getById(widget.assistant.id);
    if (current == null) return;
    final next = frames.firstWhere(
      (frame) => frame > current.gradientBackgroundPhase + 0.01,
      orElse: () => frames.first,
    );
    await provider.updateAssistant(
      current.copyWith(gradientBackgroundPhase: next),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final animated = widget.assistant.gradientBackgroundAnimated;
    final canvasSize = MediaQuery.sizeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _iosSwitchRow(
          context,
          icon: Lucide.Sparkles,
          label: l10n.assistantEditGradientBackgroundTitle,
          value: widget.assistant.useGradientBackground,
          onChanged: (value) {
            final provider = context.read<AssistantProvider>();
            final current = provider.getById(widget.assistant.id);
            if (current != null) {
              provider.updateAssistant(
                current.copyWith(useGradientBackground: value),
              );
            }
          },
        ),
        if (widget.assistant.useGradientBackground) ...[
          _iosDivider(context),
          _iosSwitchRow(
            context,
            icon: Lucide.Camera,
            label: l10n.assistantEditGradientStaticTitle,
            value: !animated,
            onChanged: _setStatic,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(60, 0, 12, 4),
            child: Text(
              l10n.assistantEditGradientStaticDescription,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.assistantEditGradientPreview,
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    if (!animated)
                      _IosButton(
                        label: l10n.assistantEditGradientNextFrame,
                        icon: Lucide.Shuffle,
                        dense: true,
                        onTap: _nextFrame,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = math.min(
                      constraints.maxWidth,
                      260 * canvasSize.aspectRatio,
                    );
                    return Center(
                      child: Container(
                        width: width,
                        height: width / canvasSize.aspectRatio,
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        // Keep the rounded border above the opaque artwork.
                        foregroundDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.35),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        // Fit the complete chat canvas, including the space between
                        // its color patches. Never recalculate blobs in a squat box.
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: canvasSize.width,
                            height: canvasSize.height,
                            child: RepaintBoundary(
                              child: ChatGradientBackgroundHost(
                                enabled: animated,
                                phase: widget.assistant.gradientBackgroundPhase,
                                offset: Offset(_x, _y),
                                onFrame: (frame) => _previewFrame = frame,
                                child: const ChatGradientBackground(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _positionSlider(
                  l10n.assistantEditGradientHorizontal,
                  _x,
                  (value) => setState(() => _x = value),
                ),
                _positionSlider(
                  l10n.assistantEditGradientVertical,
                  _y,
                  (value) => setState(() => _y = value),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _positionSlider(
    String label,
    double value,
    ValueChanged<double> onChanged,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        SfSlider(
          min: -1.0,
          max: 1.0,
          value: value,
          stepSize: 0.01,
          // Persist once on release, keeping disk writes and chat invalidation
          // out of the drag loop.
          onChanged: (dynamic next) => onChanged((next as num).toDouble()),
          onChangeEnd: (_) => _savePosition(),
        ),
      ],
    );
  }
}
