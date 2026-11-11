import importlib.util
import io
import json
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('translate', Path(__file__).with_name('translate.py'))
translate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(translate)


class TranslationContractTest(unittest.TestCase):
    def test_source_fingerprint_tracks_both_languages_and_context(self):
        en = {'save': 'Save', '@save': {'description': 'Save the draft.'}}
        zh = {'save': '保存'}
        original = translate.fingerprint(en, zh, 'save', 'ru')
        zh['save'] = '保存草稿'
        self.assertNotEqual(original, translate.fingerprint(en, zh, 'save', 'ru'))
        zh['save'] = '保存'
        en['@save']['description'] = 'Save all settings.'
        self.assertNotEqual(original, translate.fingerprint(en, zh, 'save', 'ru'))

    def test_duplicate_or_incomplete_model_keys_are_rejected(self):
        with self.assertRaises(ValueError):
            translate.loads('{"save":"A","save":"B"}')
        with self.assertRaises(ValueError):
            translate.require_values({'save': 'A', 'extra': 'B'}, ['save'])
        with self.assertRaises(ValueError):
            translate.require_values({}, ['save'])
        with self.assertRaises(ValueError):
            translate.require_values({'save': ''}, ['save'])

    def test_incomplete_output_is_retried_with_thinking_disabled(self):
        def response(reason, content):
            return io.BytesIO(json.dumps({
                'choices': [{'finish_reason': reason, 'message': {'content': content}}],
                'usage': {'total_tokens': 10},
            }).encode())
        with patch.dict(translate.os.environ, {'KELIVO_L10N_API_KEY': 'test-key'}), \
             patch.object(translate.urllib.request, 'urlopen', side_effect=[
                 response('length', ''), response('stop', '{"save":"Сохранить"}'),
             ]) as send, patch.object(translate.time, 'sleep'):
            client = translate.Client(0)
            result = client.request('Translate', {'messages': [{'key': 'save', 'en': 'Save'}]})
            self.assertEqual(result, {'save': 'Сохранить'})
            self.assertEqual(send.call_count, 2)
            payload = json.loads(send.call_args.args[0].data)
            self.assertEqual(payload['thinking'], {'type': 'disabled'})
            self.assertEqual(client.tokens, 20)

    def test_flutter_parser_handles_nested_literals_and_rejects_broken_contracts(self):
        en = {
            'valid': '{count, plural, =1{It} other{They}}',
            'renamed': 'Delete {title}?',
            'collision': '{count, plural, =1{1 result} other{{count} results}}',
            'url': 'Open https://example.com/help',
            'lines': 'First\nSecond',
        }
        errors = translate.validate(en, {
            'valid': '{count, plural, =1{bunu} other{bunları}}',
            'renamed': 'Удалить {name}?',
            'collision': '{count, plural, =1{1 результат} one{{count} результат} other{{count} результатов}}',
            'url': 'Open https://example.org/help',
            'lines': '첫째 둘째',
        })
        self.assertEqual(set(errors), {'renamed', 'collision', 'url', 'lines'})


if __name__ == '__main__':
    unittest.main()
