import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TerminalAiToolProvider extends ChangeNotifier {
  TerminalAiToolProvider({bool? initialEnabled})
    : _enabled = initialEnabled ?? false {
    if (initialEnabled == null) {
      _load().ignore();
    }
  }

  static const String prefsKey = 'terminal_ai_tools_enabled_v1';

  bool _enabled;

  bool get enabled => _enabled;

  static bool isAvailableOnCurrentPlatform() {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsKey, value);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(prefsKey) ?? false;
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
  }
}
