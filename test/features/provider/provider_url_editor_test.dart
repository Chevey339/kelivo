import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/utils/provider_url.dart';
import 'package:Kelivo/features/provider/utils/provider_url_editor.dart';

void main() {
  late TextEditingController text;
  late ProviderUrlEditor editor;
  setUp(() {
    text = TextEditingController(text: 'https://saved.example.com');
    editor = ProviderUrlEditor(text);
  });
  tearDown(() {
    editor.dispose();
    text.dispose();
  });
  const kind = ProviderKind.openai;
  test(
    'opening, focusing and saving an existing bare URL does not rewrite it',
    () {
      expect(editor.preview(kind).value, text.text);
      expect(editor.commit(kind).value, text.text);
      expect(editor.valueForSave(kind), 'https://saved.example.com');
      expect(editor.notes, isEmpty);
    },
  );
  test('draft preview normalizes, but draft is not saved until commit', () {
    text.text = 'api.example.com';
    expect(editor.preview(kind).value, 'https://api.example.com/v1');
    expect(editor.valueForSave(kind), isNull);
    expect(editor.commit(kind).value, 'https://api.example.com/v1');
    expect(text.text, 'https://api.example.com/v1');
  });
  test('invalid input cannot overwrite valid value', () {
    text.clear();
    expect(editor.error(kind), isNull);
    expect(editor.commit(kind).error, UrlError.empty);
    expect(editor.error(kind), UrlError.empty);
    expect(editor.valueForSave(kind), isNull);
    text.text = 'htps://example.com';
    expect(editor.error(kind), UrlError.invalid);
    expect(editor.commit(kind).error, UrlError.invalid);
  });
  test('undo opts out for subsequent edits', () {
    text.text = 'https://api.example.com';
    editor.commit(kind);
    expect(editor.undoAutoVersion(kind)?.value, 'https://api.example.com');
    expect(editor.autoVersionDisabled, isTrue);
    text.text = 'https://other.example.com';
    expect(editor.commit(kind).value, 'https://other.example.com');
  });
  test('manual deletion opts out before blur and is not appended again', () {
    text.text = 'https://api.example.com';
    editor.commit(kind);
    text.text = 'https://api.example.com/';
    expect(editor.preview(kind).value, 'https://api.example.com');
    expect(editor.commit(kind).value, 'https://api.example.com');
    expect(editor.autoVersionDisabled, isTrue);
  });
  test('stale undo cannot clobber a newer edit', () {
    text.text = 'https://api.example.com';
    editor.commit(kind);
    text.text = 'https://another.example.com/v3';
    expect(editor.undoAutoVersion(kind), isNull);
    expect(text.text, 'https://another.example.com/v3');
  });
  test('a provider rebuild does not replace invalid or in-progress text', () {
    text.clear();
    editor.commit(kind);
    editor.sync(
      ProviderConfig(
        id: 'a',
        enabled: true,
        name: 'a',
        apiKey: '',
        baseUrl: 'https://saved.example.com',
      ),
    );
    expect(text.text, '');
  });
}
