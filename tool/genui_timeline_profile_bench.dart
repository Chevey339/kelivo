import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../integration_test/support/message_profile_host.dart';
import '../integration_test/support/profile_measurement.dart';
import 'genui_profile_harness.dart';

/// Explicit print-only executable: flutter run --profile -t this file.
/// Copy this exact fixture to the archived C01 build for the baseline comparison.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await MessageTestServices.open();
  final probe = GenUiProfileMeasurement();
  final harness = GenUiProfileHarness();
  try {
    final key = GlobalKey<MessageProfileHostState>();
    final messages = ordinaryProfileMessages();
    await harness.mount(
      MessageProfileHost(key: key, messages: messages, services: services),
    );
    final scroll = key.currentState!.scroll;
    Future<void> traverse() async {
      final destination = math.min(scroll.position.maxScrollExtent, 12000.0);
      await scroll.animateTo(
        destination,
        duration: const Duration(seconds: 4),
        curve: Curves.linear,
      );
      await scroll.animateTo(
        0,
        duration: const Duration(seconds: 4),
        curve: Curves.linear,
      );
    }

    await traverse();
    for (var round = 0; round < 5; round++) {
      await probe.measure('scroll-$round', traverse);
    }
    await probe.measure(
      'ordinary-idle',
      () => Future<void>.delayed(const Duration(seconds: 5)),
    );
    final view = ui.PlatformDispatcher.instance.views.first;
    final report = probe.report('ordinary-200-messages')
      ..addAll({
        'profile': kProfileMode,
        'messageCount': messages.length,
        'sourceCharacters': messages.fold<int>(
          0,
          (sum, message) => sum + message.content.length,
        ),
        'viewport': '${view.physicalSize}',
        'devicePixelRatio': view.devicePixelRatio,
        'scrollExtent': scroll.position.maxScrollExtent,
      });
    // One bounded metadata line; measurements are printed individually.
    // ignore: avoid_print
    print('GENUI_PROFILE_END ${jsonEncode(report)}');
  } finally {
    await harness.mount(const SizedBox());
    await services.close();
  }
  exit(0);
}
