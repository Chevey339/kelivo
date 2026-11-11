import 'package:flutter/widgets.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/utils/provider_url.dart';

/// Shared draft/commit state for all provider URL fields. Drafts never replace
/// a saved URL until they have passed validation and been committed.
class ProviderUrlEditor extends ChangeNotifier {
  ProviderUrlEditor(this.controller, {this.autoVersionDisabled = false})
    : _acceptedText = controller.text {
    controller.addListener(_onEdit);
  }

  final TextEditingController controller;
  String _acceptedText;
  String? _autoAddedBare;
  String? _autoAddedValue;
  bool autoVersionDisabled;
  bool _writing = false;
  bool _showValidation = false;
  List<NormalizeNote> notes = const [];
  String? movedPath;

  bool get dirty => controller.text != _acceptedText;

  void _onEdit() {
    if (_writing) return;
    notes = const [];
    movedPath = null;
    notifyListeners();
  }

  bool _removedAutoVersion(ProviderKind kind) =>
      _autoAddedBare != null &&
      normalizeBaseUrl(controller.text, kind, allowAutoVersion: false).value ==
          _autoAddedBare;

  NormalizeResult preview(ProviderKind kind) {
    final result = normalizeBaseUrl(
      controller.text,
      kind,
      allowAutoVersion:
          dirty && !autoVersionDisabled && !_removedAutoVersion(kind),
    );
    // Existing valid values retain their spelling and request behavior.
    return dirty || result.error != null
        ? result
        : NormalizeResult(value: controller.text);
  }

  UrlError? error(ProviderKind kind) =>
      _showValidation ? preview(kind).error : null;

  String? valueForSave(ProviderKind kind) =>
      !dirty && preview(kind).error == null ? controller.text : null;

  NormalizeResult commit(ProviderKind kind) {
    _showValidation = true;
    final result = preview(kind);
    if (result.error != null) {
      notifyListeners();
      return result;
    }
    if (dirty) {
      if (_removedAutoVersion(kind)) autoVersionDisabled = true;
      if (result.notes.contains(NormalizeNote.addedVersion)) {
        _autoAddedBare = normalizeBaseUrl(
          controller.text,
          kind,
          allowAutoVersion: false,
        ).value;
        _autoAddedValue = result.value;
      }
      notes = result.notes;
      movedPath = result.movedPath;
      _write(result.value);
    }
    notifyListeners();
    return result;
  }

  NormalizeResult? undoAutoVersion(ProviderKind kind) {
    if (_autoAddedBare == null || controller.text != _autoAddedValue) {
      return null;
    }
    autoVersionDisabled = true;
    notes = const [];
    movedPath = null;
    _write(_autoAddedBare!);
    _autoAddedBare = null;
    _autoAddedValue = null;
    notifyListeners();
    return NormalizeResult(value: controller.text);
  }

  void sync(ProviderConfig config) {
    if (dirty) return;
    autoVersionDisabled = config.autoVersionDisabled;
    if (_acceptedText != config.baseUrl) _write(config.baseUrl);
  }

  void _write(String value) {
    _acceptedText = value;
    _writing = true;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _writing = false;
  }

  @override
  void dispose() {
    controller.removeListener(_onEdit);
    super.dispose();
  }
}

Future<void> undoSavedProviderUrl(
  SettingsProvider settings,
  String providerKey,
  String bareUrl,
  String replacedUrl,
) async {
  if (!settings.providerConfigs.containsKey(providerKey)) return;
  final current = settings.getProviderConfig(providerKey);
  if (current.baseUrl != replacedUrl) return;
  await settings.setProviderConfig(
    providerKey,
    current.copyWith(baseUrl: bareUrl, autoVersionDisabled: true),
  );
}
