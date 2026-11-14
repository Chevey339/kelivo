import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/desktop/linux_autostart.dart';

void main() {
  late Directory directory;
  late LinuxAutostart startup;
  late File entry;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo_autostart_');
    startup = LinuxAutostart(
      configDirectory: directory.path,
      executable: '/home/user/My Apps/Kelivo.AppImage',
    );
    entry = File('${directory.path}/autostart/kelivo.desktop');
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'registers a persistent executable with spaces and removes it',
    () async {
      expect(await startup.isEnabled(), isFalse);
      await startup.setEnabled(true);
      expect(
        await entry.readAsString(),
        contains('Exec="/home/user/My Apps/Kelivo.AppImage" --autostart\n'),
      );
      expect(await startup.isEnabled(), isTrue);
      await startup.setEnabled(false);
      expect(await entry.exists(), isFalse);
      await startup.setEnabled(false);
    },
  );

  test(
    'respects external desktop autostart disabling and repairs on request',
    () async {
      await startup.setEnabled(true);
      for (final setting in [
        'Hidden=true',
        'X-GNOME-Autostart-enabled=false',
      ]) {
        await entry.writeAsString('$setting\n', mode: FileMode.append);
        expect(await startup.isEnabled(), isFalse);
        await startup.setEnabled(true);
        expect(await startup.isEnabled(), isTrue);
      }
    },
  );

  test(
    'desktop quoting escapes percent field codes and reserved characters',
    () {
      expect(
        LinuxAutostart.quoteExecutable('/home/A B/100%.AppImage'),
        '"/home/A B/100%%.AppImage"',
      );
      expect(
        LinuxAutostart.quoteExecutable(r'/home/$USER/"quoted"'),
        r'"/home/\\$USER/\\"quoted\\""',
      );
    },
  );

  test('a moved executable is not reported as correctly registered', () async {
    await startup.setEnabled(true);
    final moved = LinuxAutostart(
      configDirectory: directory.path,
      executable: '/home/user/New.AppImage',
    );
    expect(await moved.isEnabled(), isFalse);
    await moved.setEnabled(true);
    expect(await moved.isEnabled(), isTrue);
  });
}
