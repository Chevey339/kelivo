import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/models/environment_variable.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/sandbox/android_proot_runtime.dart';
import 'package:Kelivo/core/services/sandbox/environment_dependencies.dart';
import 'package:Kelivo/core/services/sandbox/guest_script_runner.dart';
import 'package:Kelivo/core/services/sandbox/ios_ish_runtime.dart';
import 'package:Kelivo/core/services/workspace/environment_output_redactor.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/workspace/terminal/terminal_session_manager.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

import '../../../support/business_test_harness.dart';
import '../../../features/workspace/environment/environment_test_fakes.dart';
import 'dependency_test_runtime.dart';
import 'sandbox_channel_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SettingsProvider settings;
  late EnvironmentProvider env;

  setUp(() async {
    final harness = await createBusinessTestHarness(
      initial: {
        'global_proxy_enabled_v1': true,
        'global_proxy_type_v1': 'http',
        'global_proxy_host_v1': '127.0.0.1',
        'global_proxy_port_v1': '7890',
        'global_proxy_bypass_v1': 'localhost; 127.0.0.1,*.example.test',
      },
    );
    settings = SettingsProvider(harness.preferences);
    env = EnvironmentProvider(
      preferences: harness.preferences,
      proxySettings: settings,
    );
    addTearDown(settings.dispose);
    addTearDown(env.dispose);
  });

  test(
    'first execution waits for saved settings and keeps defaults ephemeral',
    () async {
      final config = await env.loadExecutionConfig();
      expect(config.variables, {
        'http_proxy': 'http://127.0.0.1:7890',
        'https_proxy': 'http://127.0.0.1:7890',
        'HTTPS_PROXY': 'http://127.0.0.1:7890',
        'all_proxy': 'http://127.0.0.1:7890',
        'ALL_PROXY': 'http://127.0.0.1:7890',
        'no_proxy': 'localhost,127.0.0.1,.example.test',
        'NO_PROXY': 'localhost,127.0.0.1,.example.test',
      });
      expect(env.variables, isEmpty);
      final withoutProxy = EnvironmentProvider(preferences: env.preferences);
      addTearDown(withoutProxy.dispose);
      expect((await withoutProxy.loadExecutionConfig()).variables, isEmpty);
    },
  );

  test(
    'new snapshots follow edits and disabling without changing in-flight values',
    () async {
      final first = await env.loadExecutionConfig();
      await settings.setGlobalProxyType('socks5');
      await settings.setGlobalProxyPort('1080');
      final second = await env.loadExecutionConfig();
      expect(second.variables['http_proxy'], 'socks5h://127.0.0.1:1080');
      expect(second.variables['https_proxy'], 'socks5h://127.0.0.1:1080');
      await settings.setGlobalProxyEnabled(false);
      expect((await env.loadExecutionConfig()).variables, isEmpty);
      expect(first.variables['http_proxy'], 'http://127.0.0.1:7890');
      expect(second.variables['http_proxy'], 'socks5h://127.0.0.1:1080');
    },
  );

  test(
    'encodes credentials and IPv6 while matching the app HTTP CONNECT mode',
    () async {
      await settings.loaded;
      await settings.setGlobalProxyType('https');
      await settings.setGlobalProxyHost('[::1]');
      await settings.setGlobalProxyUsername('user:@/');
      await settings.setGlobalProxyPassword('p@ss:% 空');
      final config = await env.loadExecutionConfig();
      final proxy = config.variables['https_proxy']!;
      expect(proxy, 'http://user%3A%40%2F:p%40ss%3A%25%20%E7%A9%BA@[::1]:7890');
      final result = EnvironmentOutputRedactor(
        config,
      ).redact(ClientToolResult(jsonEncode({'stdout': 'https_proxy=$proxy'})));
      expect(result.content, isNot(contains('user%3A')));
      expect(result.content, contains('[REDACTED]'));
    },
  );

  test(
    'explicit variables override automatic proxies across case variants',
    () async {
      for (final entry in {
        'ALL_PROXY': 'http://custom.test:8080',
        'HTTPS_PROXY': 'http://secure.test:8081',
        'NO_PROXY': 'internal.test',
        'TOKEN': 'keep-this-secret',
      }.entries) {
        await env.saveVariable(
          EnvironmentVariable(name: entry.key, value: entry.value),
        );
      }
      final variables = (await env.loadExecutionConfig()).variables;
      expect(variables['http_proxy'], 'http://custom.test:8080');
      expect(variables['all_proxy'], 'http://custom.test:8080');
      expect(variables['https_proxy'], 'http://secure.test:8081');
      expect(variables['no_proxy'], 'internal.test');
      expect(variables['TOKEN'], 'keep-this-secret');
      await settings.setGlobalProxyEnabled(false);
      final disabled = (await env.loadExecutionConfig()).variables;
      expect(
        disabled.keys,
        unorderedEquals(['ALL_PROXY', 'HTTPS_PROXY', 'NO_PROXY', 'TOKEN']),
      );
      expect(disabled['ALL_PROXY'], 'http://custom.test:8080');
    },
  );

  test(
    'invalid ports do not break ordinary local commands or manual variables',
    () async {
      await env.saveVariable(
        const EnvironmentVariable(name: 'TOKEN', value: 'secret'),
      );
      await settings.loaded;
      for (final port in ['', 'invalid', '0', '-1', '65536']) {
        await settings.setGlobalProxyPort(port);
        expect((await env.loadExecutionConfig()).variables, {
          'TOKEN': 'secret',
        });
      }
    },
  );

  test(
    'malformed proxy hosts preserve local tools and manual variables',
    () async {
      await env.saveVariable(
        const EnvironmentVariable(name: 'TOKEN', value: 'secret'),
      );
      await env.saveVariable(
        const EnvironmentVariable(
          name: 'https_proxy',
          value: 'http://manual.test:8080',
        ),
      );
      await settings.loaded;
      for (final host in ['[::1', 'http://127.0.0.1', 'localhost:7890']) {
        await settings.setGlobalProxyHost(host);
        expect((await env.loadExecutionConfig()).variables, {
          'TOKEN': 'secret',
          'https_proxy': 'http://manual.test:8080',
        });
      }
    },
  );

  test(
    'per-process overrides are resolved before automatic proxy defaults',
    () async {
      final config = await env.loadExecutionConfig(
        overrides: {
          'HTTPS_PROXY': 'http://mcp-proxy.test:8081',
          'TOKEN': 'server-secret',
        },
      );
      expect(config.variables['https_proxy'], 'http://mcp-proxy.test:8081');
      expect(config.variables['HTTPS_PROXY'], 'http://mcp-proxy.test:8081');
      expect(config.variables['http_proxy'], 'http://127.0.0.1:7890');
      expect(config.variables['TOKEN'], 'server-secret');
      expect(env.variables, isEmpty);
    },
  );

  for (final alpine in [false, true]) {
    test(
      '${alpine ? 'apk' : 'apt'} installation receives fresh proxy and user variables',
      () async {
        await env.loaded;
        await env.setState(
          EnvironmentState(
            phase: EnvironmentPhase.ready,
            distro: alpine ? 'alpine' : 'ubuntu',
          ),
        );
        await env.saveVariable(
          const EnvironmentVariable(name: 'TOKEN', value: 'secret'),
        );
        final runtime = DependencyTestRuntime();
        final service = EnvironmentDependencies(
          runtime: runtime,
          env: env,
          alpine: alpine,
          mirrors: FakeMirrorService(env),
        );
        addTearDown(service.dispose);
        await service.install(EnvironmentDependency.python);
        expect(service.failure, isNull);
        expect(runtime.requests, isNotEmpty);
        for (final request in runtime.requests) {
          expect(request.env['http_proxy'], 'http://127.0.0.1:7890');
          expect(request.env['TOKEN'], 'secret');
        }
        runtime.requests.clear();
        await settings.setGlobalProxyEnabled(false);
        await service.install(EnvironmentDependency.node);
        expect(service.failure, isNull);
        expect(
          runtime.requests.every((r) => !r.env.containsKey('http_proxy')),
          isTrue,
        );
      },
    );
  }

  for (final android in [true, false]) {
    test(
      '${android ? 'Android' : 'iOS'} exec and new terminals forward the current proxy',
      () async {
        final workspace = SandboxChannelHarness()..install();
        addTearDown(workspace.dispose);
        workspace.handler = (call) {
          if (call.method == 'probe') return workspace.probeResult;
          if (call.method == 'exec') {
            final args = call.arguments as Map;
            workspace.emit({
              'type': 'exit',
              'runId': args['runId'],
              'exitCode': 0,
            });
          }
          if (call.method == 'ptyOpen') return {'pid': 42};
          return null;
        };
        final rootfs = await Directory.systemTemp.createTemp(
          'kelivo-proxy-test-',
        );
        addTearDown(() => rootfs.delete(recursive: true));
        await env.loaded;
        await env.setState(
          const EnvironmentState(phase: EnvironmentPhase.ready),
        );
        final WorkspaceRuntime runtime = android
            ? AndroidProotRuntime(
                channel: workspace.channel,
                env: env,
                rootfsDir: rootfs,
                tmpDir: rootfs,
              )
            : IosIshRuntime(channel: workspace.channel);
        final manager = TerminalSessionManager(
          setWakelock: (_) async {},
          loadEnvironment: () async =>
              (await env.loadExecutionConfig()).variables,
        );
        addTearDown(() async {
          await manager.closeAll();
          manager.dispose();
        });
        final config = await env.loadExecutionConfig();
        expect(
          await runGuestScript(runtime, 'true', environment: config.variables),
          0,
        );
        expect(
          (workspace.argsOf('exec')!['env'] as Map)['http_proxy'],
          'http://127.0.0.1:7890',
        );
        await manager.open(runtime: runtime, mounts: const [], cwd: '/root');
        expect(
          (workspace.argsOf('ptyOpen')!['env'] as Map)['https_proxy'],
          'http://127.0.0.1:7890',
        );
        workspace.calls.clear();
        await settings.setGlobalProxyEnabled(false);
        await manager.open(runtime: runtime, mounts: const [], cwd: '/root');
        final fresh = workspace.argsOf('ptyOpen')!['env'] as Map;
        expect(fresh.containsKey('http_proxy'), isFalse);
        expect(fresh['TERM'], 'xterm-256color');
      },
    );
  }

  test(
    'real curl uses the generated proxy, authentication and bypass variables',
    () async {
      final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => proxy.close(force: true));
      addTearDown(() => origin.close(force: true));
      final requests = <HttpRequest>[];
      proxy.listen((request) async {
        requests.add(request);
        await request.drain<void>();
        request.response.write('proxied');
        await request.response.close();
      });
      origin.listen((request) async {
        await request.drain<void>();
        request.response.write('direct');
        await request.response.close();
      });
      await settings.loaded;
      await settings.setGlobalProxyPort('${proxy.port}');
      await settings.setGlobalProxyUsername('user@name');
      await settings.setGlobalProxyPassword('p:ss/%');
      Future<ProcessResult> curl(String url) async => Process.run(
        '/usr/bin/curl',
        ['-q', '--verbose', '--silent', '--show-error', '--max-time', '5', url],
        environment: (await env.loadExecutionConfig()).variables,
        includeParentEnvironment: false,
      );
      final proxied = await curl('http://sandbox-proxy.invalid/resource');
      expect(proxied.exitCode, 0, reason: '${proxied.stderr}');
      expect(proxied.stdout, 'proxied');
      expect(
        requests.single.uri.toString(),
        'http://sandbox-proxy.invalid/resource',
      );
      expect(
        requests.single.headers.value(HttpHeaders.proxyAuthorizationHeader),
        'Basic ${base64Encode(utf8.encode('user@name:p:ss/%'))}',
      );
      final auth = base64Encode(utf8.encode('user@name:p:ss/%'));
      expect(proxied.stderr, contains('Proxy-Authorization: Basic $auth'));
      final redacted = EnvironmentOutputRedactor(
        await env.loadExecutionConfig(),
      ).redact(ClientToolResult(jsonEncode({'stderr': proxied.stderr})));
      for (final secret in [auth, 'user@name', 'p:ss/%', 'user%40name']) {
        expect(redacted.content, isNot(contains(secret)));
      }
      final direct = await curl('http://127.0.0.1:${origin.port}/');
      expect(direct.exitCode, 0, reason: '${direct.stderr}');
      expect(direct.stdout, 'direct');
      expect(requests, hasLength(1));
      await settings.setGlobalProxyBypass('');
      await settings.setGlobalProxyEnabled(false);
      final disabled = await curl('http://127.0.0.1:${origin.port}/');
      expect(disabled.stdout, 'direct');
      expect(requests, hasLength(1));
    },
    skip: !File('/usr/bin/curl').existsSync(),
  );
}
