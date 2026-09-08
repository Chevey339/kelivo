import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'chat_gradient_background.dart';

@Preview(
  name: 'Gradient · light',
  size: Size(390, 780),
  brightness: Brightness.light,
)
@Preview(
  name: 'Gradient · dark',
  size: Size(390, 780),
  brightness: Brightness.dark,
)
@Preview(name: 'Gradient · desktop', size: Size(1100, 720))
Widget chatGradientBackgroundPreview() => const ChatGradientBackgroundHost(
  enabled: true,
  phase: 7,
  child: ChatGradientBackground(),
);

@Preview(name: 'Static gradient · position', size: Size(390, 780))
Widget chatStaticGradientBackgroundPreview() =>
    const ChatGradientBackgroundHost(
      enabled: false,
      phase: 7,
      offset: Offset(-0.3, 0.4),
      child: ChatGradientBackground(),
    );
