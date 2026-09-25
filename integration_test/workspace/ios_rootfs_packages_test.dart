import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/environment_dependencies.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/sandbox/guest_script_runner.dart';
import 'package:Kelivo/core/services/sandbox/ios_ish_runtime.dart';
import 'package:Kelivo/core/services/sandbox/mirror_service.dart';
import 'package:Kelivo/core/services/sandbox/mirror_speed_test.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Run on a disposable simulator: this test starts with a fresh environment.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'release metadata survives Python installation, update and in-place repair',
    (tester) async {
      final channel = WorkspaceChannel();
      final runtime = IosIshRuntime(channel: channel);
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final env = EnvironmentProvider(
        preferences: BusinessPreferences(BusinessRepository(database)),
      );
      await env.loaded;
      addTearDown(env.dispose);
      final manager = IosRootfsManager(channel: channel, env: env);
      expect((await channel.probe()).booted, isFalse);
      await manager.reset();
      await manager.install();
      expect(env.state.phase, EnvironmentPhase.ready);

      var sequence = 0;
      Future<String> run(String script) async {
        final output = StringBuffer();
        CommandExited? exit;
        await for (final event in runtime.run(
          CommandRequest(
            runId: 'rootfs-regression-${++sequence}',
            command: script,
            cwd: '/',
            timeout: const Duration(minutes: 10),
          ),
        )) {
          if (event is CommandOutput) {
            output.write(utf8.decode(event.bytes, allowMalformed: true));
          } else if (event is CommandExited) {
            exit = event;
          }
        }
        expect(exit?.exitCode, 0, reason: '$script\n$output');
        return output.toString();
      }

      Future<void> checkRelease() async {
        final result = await run(r'''
set -eu
cat /etc/os-release
test -s /etc/alpine-release
apk info --installed alpine-release musl bash coreutils libc-utils
apk --no-network --repositories-file /dev/null add --simulate musl
''');
        expect(result, contains('ID=alpine'));
        expect(result, isNot(contains('Purging')));
      }

      await checkRelease();
      final mirrors = MirrorService(
        env: env,
        speedTest: MirrorSpeedTest(),
        runInGuest: (script) => runGuestScript(runtime, script),
      );
      final dependencies = EnvironmentDependencies(
        runtime: runtime,
        env: env,
        alpine: true,
        mirrors: mirrors,
      );
      addTearDown(dependencies.dispose);
      await dependencies.install(EnvironmentDependency.python);
      expect(dependencies.failure, isNull, reason: dependencies.log);
      expect(
        dependencies.status(EnvironmentDependency.python),
        DependencyStatus.installed,
      );
      await checkRelease();
      expect(
        await run(
          "python3 -c 'import platform; print(platform.freedesktop_os_release()[\"ID\"])'",
        ),
        contains('alpine'),
      );

      // Model an already-purged environment with additional user software.
      await run(r'''
set -eu
apk --wait 60 add tree
printf 'keep me' > /root/kelivo-repair-sentinel
apk --wait 60 del alpine-release
test ! -e /etc/os-release
''');
      final before = await channel.probe();
      final versionFile = File('${before.rootfsDir}/.version');
      await versionFile.writeAsString('alpine-3.21.3-r4\n');
      expect(await manager.checkForUpdate(), isTrue);
      await manager.install();
      expect(env.state.phase, EnvironmentPhase.ready);
      expect((await channel.probe()).rootfsVersion, before.bundledVersion);
      await checkRelease();
      await run(r'''
set -eu
test "$(cat /root/kelivo-repair-sentinel)" = 'keep me'
apk info --installed tree python3 py3-pip py3-virtualenv
python3 -c 'import platform; assert platform.freedesktop_os_release()["ID"] == "alpine"'
''');

      // Also repair missing files while the package is still registered.
      await run('rm /etc/os-release /usr/lib/os-release /etc/alpine-release');
      await manager.repair();
      expect(env.state.phase, EnvironmentPhase.ready);
      await checkRelease();

      // Database entries alone do not prove that commands or their shared
      // libraries still exist, contain executable code, or have execute bits.
      await run(r'''
set -eu
rm /bin/bash /usr/lib/libreadline.so.8.2
printf 'damaged executable\n' > /usr/bin/env
chmod a-x /bin/ls
apk info --installed bash readline coreutils coreutils-env
''');
      await manager.repair();
      expect(env.state.phase, EnvironmentPhase.ready);
      await run(r'''
set -eu
/bin/bash --noprofile --norc -c 'test -n "$BASH_VERSION"'
/bin/ls --version
/usr/bin/env --version
test "$(cat /root/kelivo-repair-sentinel)" = 'keep me'
apk info --installed tree python3 py3-pip py3-virtualenv
''');
      await checkRelease();
      await manager.repair();
      expect(env.state.phase, EnvironmentPhase.ready);
      await run('apk info --installed tree python3');
    },
    skip: !Platform.isIOS,
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
