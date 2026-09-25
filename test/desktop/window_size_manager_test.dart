import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/desktop/window_size_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const manager = WindowSizeManager();

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Windows discards legacy logical positions with unknown DPI', () async {
    SharedPreferences.setMockInitialValues({
      'window_pos_x_v1': 1600.0,
      'window_pos_y_v1': 200.0,
      'window_width_v1': 1400.0,
      'window_height_v1': 900.0,
    });
    expect(await manager.getPosition(), isNull);
    expect(await manager.getInitialSize(), const Size(1400, 900));
  });

  test('physical positions beyond 10000 pixels survive a round trip', () async {
    const position = Offset(-14200, 1500);
    await manager.setPosition(position);
    expect(await manager.getPosition(), position);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('window_physical_pos_x_v1'), -14200);
    expect(prefs.containsKey('window_pos_x_v1'), isFalse);
  });

  test('non-finite positions do not replace the last valid position', () async {
    await manager.setPosition(const Offset(-1200, 100));
    await manager.setPosition(const Offset(double.nan, double.infinity));
    expect(await manager.getPosition(), const Offset(-1200, 100));
  });

  test('corrupt stored physical coordinates are rejected', () async {
    SharedPreferences.setMockInitialValues({
      'window_physical_pos_x_v1': double.infinity,
      'window_physical_pos_y_v1': 100.0,
    });
    expect(await manager.getPosition(), isNull);
  });

  test('Linux keeps its existing logical coordinate keys', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await manager.setPosition(const Offset(-1600, 100));
    expect(await manager.getPosition(), const Offset(-1600, 100));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('window_pos_x_v1'), -1600);
    expect(prefs.containsKey('window_physical_pos_x_v1'), isFalse);
  });
}
