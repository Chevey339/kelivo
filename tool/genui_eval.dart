import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'genui_eval/prompt.dart';
import 'genui_eval/run_output.dart';
import 'genui_eval/runtime.dart';
import 'genui_eval/scoring.dart';

final class _Failure implements Exception {
  const _Failure(this.message);
  final String message;
}

Future<void> main(List<String> args) async {
  try {
    await _run(args);
  } on _Failure catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on TimeoutException {
    stderr.writeln('Request timed out; no automatic retry was made.');
    exitCode = 1;
  } catch (_) {
    // Exception objects can embed response bodies, URLs or request headers.
    stderr.writeln(
      'Evaluation failed. Check configuration, local files and connectivity; sensitive exception details were omitted.',
    );
    exitCode = 1;
  }
}

Future<void> _run(List<String> args) async {
  String? configPath;
  String? outputPath;
  var early = false;
  var summarize = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--config':
        if (++i >= args.length) throw const _Failure('Missing --config value.');
        configPath = args[i];
      case '--output':
        if (++i >= args.length) throw const _Failure('Missing --output value.');
        outputPath = args[i];
      case '--early':
        early = true;
      case '--summarize':
        summarize = true;
      default:
        throw const _Failure(
          'Usage: dart run tool/genui_eval.dart --config tool/genui_eval/config.json --output build/genui_eval/run-name [--early] [--summarize]',
        );
    }
  }
  if (configPath == null || outputPath == null) {
    throw const _Failure('--config and --output are required.');
  }
  final config =
      jsonDecode(await File(configPath).readAsString()) as Map<String, dynamic>;
  final model = config['model'] as String;
  if (model.trim().isEmpty) throw const _Failure('A model ID is required.');
  final allTasks = (config['tasks'] as List)
      .map((value) => GenUiEvalTask.fromJson(value as Map<String, dynamic>))
      .toList();
  if (allTasks.length != 30 ||
      allTasks.map((task) => task.id).toSet().length != 30 ||
      allTasks.where((task) => task.early).length != 3) {
    throw const _Failure('Expected the frozen 30 tasks and 3 early tasks.');
  }
  final tasks = allTasks.where((task) => !early || task.early).toList();
  final rootResult = await Process.run('git', ['rev-parse', '--show-toplevel']);
  if (rootResult.exitCode != 0) {
    throw const _Failure('Run from the implementation repository.');
  }
  final root = await Directory(
    (rootResult.stdout as String).trim(),
  ).resolveSymbolicLinks();
  final configFile = await File(configPath).resolveSymbolicLinks();
  final entrypoint = await File.fromUri(Platform.script).resolveSymbolicLinks();
  if (!p.isWithin(p.join(root, 'tool', 'genui_eval'), configFile) ||
      entrypoint != p.join(root, 'tool', 'genui_eval.dart')) {
    throw const _Failure(
      'Use the repository entrypoint and a tracked configuration under tool/genui_eval; external input copies cannot be attributed to HEAD.',
    );
  }
  final trackedConfig = await Process.run('git', [
    'ls-files',
    '--error-unmatch',
    '--',
    p.relative(configFile, from: root),
  ], workingDirectory: root);
  if (trackedConfig.exitCode != 0) {
    throw const _Failure(
      'The evaluation configuration must be tracked by Git.',
    );
  }
  final trackedInputs = [
    'lib/features/intelligent_ui',
    'assets/skills/visualize',
    'tool/genui_eval.dart',
    'tool/genui_eval',
    'dependencies/markstream',
    'pubspec.yaml',
    'pubspec.lock',
    'pubspec_overrides.yaml',
  ];
  final status = await Process.run('git', [
    'status',
    '--porcelain',
    '--',
    ...trackedInputs,
  ], workingDirectory: root);
  if (status.exitCode != 0 || (status.stdout as String).trim().isNotEmpty) {
    throw const _Failure(
      'Commit evaluation code/configuration before a manual run; testedCommit must describe the real inputs.',
    );
  }
  try {
    await verifyEvaluationRuntime(
      root,
      config['runtime'] as Map<String, dynamic>,
    );
  } on FormatException {
    throw const _Failure(
      'The SDK, local parser or resolved evaluator dependencies differ from the frozen configuration. Restore the configured resolution or commit an intentional evaluation update.',
    );
  }
  final output = Directory(outputPath);
  final configuration = p.relative(configFile, from: root);
  if (summarize) {
    await _summarize(output, tasks, model, root, trackedInputs, configuration);
    return;
  }

  final env = Platform.environment;
  final key = env['GENUI_EVAL_API_KEY'];
  final rawUrl = env['GENUI_EVAL_BASE_URL'];
  if (key == null || key.isEmpty || rawUrl == null || rawUrl.isEmpty) {
    throw const _Failure(
      'Set GENUI_EVAL_API_KEY and GENUI_EVAL_BASE_URL in the process environment. No app accounts are read.',
    );
  }
  final endpoint = Uri.parse(rawUrl);
  if (endpoint.scheme != 'https' ||
      endpoint.host.isEmpty ||
      endpoint.userInfo.isNotEmpty ||
      endpoint.hasQuery ||
      endpoint.hasFragment ||
      !endpoint.path.endsWith('/chat/completions')) {
    throw const _Failure(
      'GENUI_EVAL_BASE_URL must be the complete HTTPS /chat/completions endpoint without credentials, query or fragment.',
    );
  }
  final commitResult = await Process.run('git', [
    'rev-parse',
    'HEAD',
  ], workingDirectory: root);
  if (commitResult.exitCode != 0) {
    throw const _Failure('Unable to record the tested commit.');
  }
  final commit = (commitResult.stdout as String).trim();
  final date = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  try {
    await claimEvaluationOutput(output);
  } on FileSystemException {
    throw const _Failure(
      'Could not claim the output directory. Use a new empty writable directory; previous or concurrent first rounds cannot be overwritten.',
    );
  }
  final metadata = {'model': model, 'date': date, 'testedCommit': commit};
  await _writeJson(File('${output.path}/run.json'), {
    ...metadata,
    'tasks': tasks.map((task) => task.id).toList(),
    'phase': early ? 'early' : 'final',
    'configuration': configuration,
  });
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    for (final task in tasks) {
      stdout.writeln('${task.id}: requesting first-round output');
      final response = await _request(client, endpoint, key, {
        'model': model,
        'temperature': config['temperature'],
        'max_tokens': config['maxTokens'],
        'stream': false,
        'messages': [
          {'role': 'system', 'content': genUiEvaluationPrompt()},
          {'role': 'user', 'content': task.prompt},
        ],
      }).timeout(const Duration(minutes: 3));
      // Only synthetic task text is retained. Never save headers or raw error bodies.
      final sanitized = response.content.replaceAll(key, '[REDACTED]');
      final score = scoreGenUiOutput(task, sanitized);
      await _writeJson(File('${output.path}/${task.id}.json'), {
        ...metadata,
        'task': task.id,
        'response': sanitized,
        'finishReason': response.finishReason,
        'score': score.toJson(),
        'manualChecks': task.manualChecks,
        'semanticReview': null,
      });
      stdout.writeln(
        '${task.id}: deterministic=${score.deterministicPassed}, semantic review pending',
      );
    }
  } finally {
    client.close(force: true);
  }
  stdout.writeln(
    'First round saved. Review each response and fill semanticReview with reviewer, accepted and notes, then run --summarize. Identify agent review as such. No paid retries are automatic.',
  );
}

Future<({String content, String finishReason})> _request(
  HttpClient client,
  Uri endpoint,
  String key,
  Map<String, Object?> body,
) async {
  final request = await client.postUrl(endpoint);
  request.followRedirects = false;
  request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
  request.headers.contentType = ContentType.json;
  request.write(jsonEncode(body));
  final response = await request.close();
  if (response.statusCode != HttpStatus.ok) {
    throw _Failure(
      'Provider returned HTTP ${response.statusCode}; stopped without an automatic retry.',
    );
  }
  final bytes = <int>[];
  await for (final chunk in response) {
    if (bytes.length + chunk.length > 4 * 1024 * 1024) {
      throw const _Failure('Provider response exceeds the byte limit.');
    }
    bytes.addAll(chunk);
  }
  final raw = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  final choices = raw['choices'];
  if (choices is! List || choices.length != 1) {
    throw const _Failure('Expected one completion choice.');
  }
  final choice = choices.single as Map<String, dynamic>;
  final message = choice['message'] as Map<String, dynamic>;
  final content = message['content'];
  if (content is! String || content.isEmpty || message['tool_calls'] != null) {
    throw const _Failure(
      'Expected a nonempty text response, without tool calls.',
    );
  }
  final reason = choice['finish_reason'];
  return (
    content: content,
    finishReason: reason is String ? reason : 'unknown',
  );
}

Future<void> _summarize(
  Directory output,
  List<GenUiEvalTask> tasks,
  String model,
  String root,
  List<String> trackedInputs,
  String configuration,
) async {
  final manifest =
      jsonDecode(await File('${output.path}/run.json').readAsString())
          as Map<String, dynamic>;
  if (manifest['model'] != model ||
      manifest['configuration'] != configuration ||
      jsonEncode(manifest['tasks']) !=
          jsonEncode(tasks.map((task) => task.id).toList())) {
    throw const _Failure(
      'Run metadata does not match this model and task set.',
    );
  }
  final commit = manifest['testedCommit'] as String;
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
    throw const _Failure('Invalid tested commit.');
  }
  final unchanged = await Process.run('git', [
    'diff',
    '--quiet',
    commit,
    '--',
    ...trackedInputs,
  ], workingDirectory: root);
  if (unchanged.exitCode != 0) {
    throw const _Failure(
      'Evaluation inputs or interpretation changed after the tested commit. Results cannot be combined with this configuration.',
    );
  }
  var passed = 0;
  for (final task in tasks) {
    final result =
        jsonDecode(await File('${output.path}/${task.id}.json').readAsString())
            as Map<String, dynamic>;
    final review = result['semanticReview'];
    if (result['model'] != model ||
        result['testedCommit'] != commit ||
        result['date'] != manifest['date'] ||
        result['task'] != task.id ||
        review is! Map ||
        review['accepted'] is! bool ||
        review['reviewer'] is! String ||
        (review['reviewer'] as String).trim().isEmpty ||
        review['notes'] is! String ||
        (review['notes'] as String).trim().isEmpty) {
      throw const _Failure(
        'Every first-round result needs matching metadata and an explicit attributed semantic review.',
      );
    }
    final score = scoreGenUiOutput(task, result['response'] as String);
    if (score.deterministicPassed &&
        review['accepted'] == true &&
        result['finishReason'] == 'stop') {
      passed++;
    }
  }
  final report = {
    'model': model,
    'date': manifest['date'],
    'testedCommit': commit,
    'score':
        '$passed/${tasks.length} (${(100 * passed / tasks.length).toStringAsFixed(2)}%)',
  };
  await _writeJson(File('${output.path}/report.json'), report);
  stdout.writeln(jsonEncode(report));
  if (tasks.length == 30 && passed < 29) {
    throw const _Failure(
      'Final acceptance is incomplete: at least 29/30 first-round valid results are required.',
    );
  }
}

Future<void> _writeJson(File file, Map<String, Object?> value) =>
    file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(value)}\n',
      flush: true,
    );
