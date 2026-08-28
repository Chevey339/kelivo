import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderConfig _cfg({
  required ProviderKind kind,
  required String baseUrl,
  required String modelId,
  List<String> builtInTools = const ['code_execution'],
}) {
  return ProviderConfig(
    id: 'Test',
    enabled: true,
    name: 'Test',
    apiKey: 'k',
    baseUrl: baseUrl,
    providerType: kind,
    modelOverrides: {
      modelId: {'builtInTools': builtInTools},
    },
  );
}

void main() {
  group('BuiltInToolsHelper.sendsDataFilesToSandbox', () {
    const claudeModel = 'claude-sonnet-4-5-20250929';

    test('official Claude with code execution on', () {
      expect(
        BuiltInToolsHelper.sendsDataFilesToSandbox(
          cfg: _cfg(
            kind: ProviderKind.claude,
            baseUrl: 'https://api.anthropic.com',
            modelId: claudeModel,
          ),
          modelId: claudeModel,
        ),
        isTrue,
      );
    });

    test('a client tool named code_execution takes the files with it', () {
      final cfg = _cfg(
        kind: ProviderKind.claude,
        baseUrl: 'https://api.anthropic.com',
        modelId: claudeModel,
      );
      // The hosted tool gives way to the client's, and so does the upload.
      expect(
        BuiltInToolsHelper.sendsDataFilesToSandbox(
          cfg: cfg,
          modelId: claudeModel,
          clientToolNames: ['get_weather', 'code_execution'],
        ),
        isFalse,
      );
      expect(
        BuiltInToolsHelper.sendsDataFilesToSandbox(
          cfg: cfg,
          modelId: claudeModel,
          clientToolNames: ['get_weather'],
        ),
        isTrue,
      );
    });

    test('official Claude without the tool', () {
      expect(
        BuiltInToolsHelper.sendsDataFilesToSandbox(
          cfg: _cfg(
            kind: ProviderKind.claude,
            baseUrl: '',
            modelId: claudeModel,
            builtInTools: const ['web_fetch'],
          ),
          modelId: claudeModel,
        ),
        isFalse,
      );
    });

    test('Claude-compatible relay never uploads', () {
      expect(
        BuiltInToolsHelper.sendsDataFilesToSandbox(
          cfg: _cfg(
            kind: ProviderKind.claude,
            baseUrl: 'https://relay.example.com',
            modelId: claudeModel,
          ),
          modelId: claudeModel,
        ),
        isFalse,
      );
    });

    test('Gemini shares the tool name but takes no files', () {
      const geminiModel = 'gemini-3-pro';
      expect(
        BuiltInToolsHelper.getActiveTools(
          cfg: _cfg(
            kind: ProviderKind.google,
            baseUrl: '',
            modelId: geminiModel,
          ),
          modelId: geminiModel,
        ).codeExecutionActive,
        isTrue,
        reason: 'the shared name is exactly why the predicate exists',
      );
      expect(
        BuiltInToolsHelper.sendsDataFilesToSandbox(
          cfg: _cfg(
            kind: ProviderKind.google,
            baseUrl: '',
            modelId: geminiModel,
          ),
          modelId: geminiModel,
        ),
        isFalse,
      );
    });
  });

  group('isSandboxDataFile', () {
    test('tabular and structured data by extension', () {
      for (final name in ['sales.CSV', 'a.xlsx', 'x.json', 'd.parquet']) {
        expect(
          isSandboxDataFile(fileName: name, mime: ''),
          isTrue,
          reason: name,
        );
      }
    });

    test('prose stays in the prompt', () {
      for (final name in ['notes.txt', 'README.md', 'spec.pdf', 'r.docx']) {
        expect(
          isSandboxDataFile(fileName: name, mime: 'application/octet-stream'),
          isFalse,
          reason: name,
        );
      }
    });

    test('a file without an extension stays in the prompt', () {
      // Pickers call a Dockerfile an octet stream; it reads fine as text.
      for (final mime in ['application/octet-stream', 'text/plain', '']) {
        expect(
          isSandboxDataFile(fileName: 'Dockerfile', mime: mime),
          isFalse,
          reason: mime,
        );
      }
    });
  });
}
