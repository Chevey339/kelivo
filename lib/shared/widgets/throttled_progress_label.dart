import 'dart:async';

import 'package:flutter/widgets.dart';

class ThrottledProgressLabel extends StatefulWidget {
  const ThrottledProgressLabel({
    super.key,
    required this.text,
    required this.builder,
    this.forceImmediate = false,
  });

  static const displayInterval = Duration(milliseconds: 1200);

  final String text;
  final Widget Function(BuildContext context, String displayText) builder;
  final bool forceImmediate;

  @override
  State<ThrottledProgressLabel> createState() => _ThrottledProgressLabelState();
}

class _ThrottledProgressLabelState extends State<ThrottledProgressLabel> {
  Timer? _timer;
  late String _displayText;
  late DateTime _lastDisplayUpdate;

  @override
  void initState() {
    super.initState();
    _displayText = widget.text;
    _lastDisplayUpdate = DateTime.now();
  }

  @override
  void didUpdateWidget(covariant ThrottledProgressLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text == _displayText) {
      return;
    }
    final elapsed = DateTime.now().difference(_lastDisplayUpdate);
    if (widget.forceImmediate ||
        elapsed >= ThrottledProgressLabel.displayInterval) {
      _applyDisplay(widget.text);
      return;
    }
    _timer ??= Timer(ThrottledProgressLabel.displayInterval - elapsed, () {
      _timer = null;
      if (!mounted) return;
      _applyDisplay(widget.text);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _applyDisplay(String text) {
    _timer?.cancel();
    _timer = null;
    _lastDisplayUpdate = DateTime.now();
    if (mounted) {
      setState(() => _displayText = text);
    } else {
      _displayText = text;
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _displayText);
}
