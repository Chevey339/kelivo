"""Run the production Gboard integration fixture with a separate Android UI driver.

Build first:
  flutter build apk --debug --target-platform android-arm64 \
    --target integration_test/native_message_ime_test.dart
Then, on an isolated AVD with Chinese Pinyin Gboard configured:
  python3 tool/run_native_ime_integration.py --device emulator-5554
Artifacts stay in .dart_tool/native-ime/integration/ by default.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import time
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--device', default='emulator-5554')
parser.add_argument('--sdk', type=Path, default=Path(os.environ.get('ANDROID_HOME', Path.home() / 'Library/Android/sdk')))
parser.add_argument('--flutter', default=shutil.which('flutter'))
parser.add_argument('--apk', type=Path, default=ROOT / 'build/app/outputs/flutter-apk/app-debug.apk')
parser.add_argument('--output', type=Path, default=ROOT / '.dart_tool/native-ime/integration')
args = parser.parse_args()
if not args.flutter:
    parser.error('Pass --flutter or put Flutter on PATH')
out = args.output / str(time.time_ns())
out.mkdir(parents=True)
adb = [str(args.sdk / 'platform-tools/adb'), '-s', args.device]


def run(command, **options):
    try:
        return subprocess.run([str(x) for x in command], check=True, capture_output=True,
                              text=True, **options)
    except subprocess.CalledProcessError as error:
        print(error.stdout + error.stderr, flush=True)
        raise


def build_driver():
    sdk_tools = args.sdk / 'build-tools/36.1.0'
    android = args.sdk / 'platforms/android-36/android.jar'
    sources = ROOT / 'tool/native_ime_driver'
    classes = out / 'classes'
    dex = out / 'dex'
    classes.mkdir(); dex.mkdir()
    run(['javac', '-source', '8', '-target', '8', '-bootclasspath', android,
         '-d', classes, sources / 'KeyboardDriver.java'])
    run([sdk_tools / 'd8', '--lib', android, '--min-api', '24', '--output', dex,
         *classes.rglob('*.class')])
    unsigned = out / 'unsigned.apk'
    run([sdk_tools / 'aapt2', 'link', '-I', android, '--manifest',
         sources / 'AndroidManifest.xml', '-o', unsigned])
    with zipfile.ZipFile(unsigned, 'a', compression=zipfile.ZIP_DEFLATED) as archive:
        archive.write(dex / 'classes.dex', 'classes.dex')
    aligned = out / 'driver.apk'
    run([sdk_tools / 'zipalign', '-f', '4', unsigned, aligned])
    run([sdk_tools / 'apksigner', 'sign', '--ks', Path.home() / '.android/debug.keystore',
         '--ks-key-alias', 'androiddebugkey', '--ks-pass', 'pass:android',
         '--key-pass', 'pass:android', aligned])
    run(adb + ['install', '-r', '-t', aligned])


build_driver()
command = [args.flutter, 'drive', '--no-pub', '--driver=test_driver/integration_test.dart',
           '--target=integration_test/native_message_ime_test.dart',
           '--use-application-binary=' + str(args.apk), '-d', args.device]
observations = []
case_results = []
result = None
run_id = None
forwarded_port = None
allowed = {'@editing', '@keyboard', '@ctrlA', '@ctrlX', '@ctrlV', '@ctrlZ', '@ctrlShiftZ', '全选', '剪切',
           '打开选择模式', '右移光标', '将光标向下移', '上移光标', '删除', 'n', 'i', '你', 'Enter 键'}
process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True, bufsize=1)
try:
    with (out / 'flutter.log').open('w') as log:
        for line in process.stdout:
            log.write(line); log.flush()
            if 'NATIVE_IME_READY ' in line:
                request = json.loads(line.split('NATIVE_IME_READY ', 1)[1])
                if run_id is None: run_id = request['runId']
                assert request['runId'] == run_id
                if forwarded_port is None:
                    forwarded_port = int(run(adb + ['forward', 'tcp:0',
                        'tcp:' + str(int(request['port']))]).stdout.strip())
                name = request['case']
                assert re.fullmatch('[a-z_]+', name)
                assert all(action in allowed for action in request['actions'].split('|'))
                print('Gboard:', name, flush=True)
                shell = 'am instrument -w -r -e run_id {} -e actions {} -e delay {} dev.kelivo.ime.driver/.KeyboardDriver'.format(
                    shlex.quote(run_id), shlex.quote(request['actions']), int(request['delay']))
                execution = run(adb + ['shell', shell], timeout=60)
                (out / (name + '.log')).write_text(execution.stdout + execution.stderr)
                match = re.search(r'^INSTRUMENTATION_RESULT: result=(.*)$', execution.stdout, re.MULTILINE)
                assert match, 'Instrumentation did not return a fresh result'
                observed = json.loads(match.group(1))
                assert observed['runId'] == run_id and observed['actions'] == request['actions']
                assert observed['pass'] and observed['performed'] == request['actions'].split('|'), observed
                observations.append({'case': name, **observed})
                acknowledgement = urllib.request.Request(
                    'http://127.0.0.1:{}/{}/{}'.format(forwarded_port, run_id, name),
                    data=b'', method='POST')
                with urllib.request.urlopen(acknowledgement, timeout=10) as response:
                    assert response.status == 204
            elif 'NATIVE_IME_CASE ' in line:
                case = json.loads(line.split('NATIVE_IME_CASE ', 1)[1])
                assert case['runId'] == run_id and case['pass']
                case_results.append(case)
            elif 'NATIVE_IME_RESULT ' in line:
                result = json.loads(line.split('NATIVE_IME_RESULT ', 1)[1])
    if process.wait() != 0:
        raise RuntimeError('Flutter integration failed; see ' + str(out / 'flutter.log'))
    assert result and result['runId'] == run_id and result['cases'] == 18
    assert len(case_results) == 18 and len({case['case'] for case in case_results}) == 18
    assert len(observations) == 20
    report = {'apkSha256': hashlib.sha256(args.apk.read_bytes()).hexdigest(),
              'dart': {'runId': run_id, 'cases': case_results}, 'ui': observations}
    (out / 'result.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print('PASS: 18 production cases, 20 identified Gboard UI segments. ' + str(out), flush=True)
except BaseException:
    process.terminate()
    try:
        process.wait(timeout=15)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
    raise
finally:
    if forwarded_port is not None:
        run(adb + ['forward', '--remove', 'tcp:' + str(forwarded_port)])
