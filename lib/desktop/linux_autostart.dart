import 'dart:io';

import 'package:path/path.dart' as p;

/// XDG autostart entry. AppImage callers supply the persistent AppImage path.
class LinuxAutostart {
  LinuxAutostart({required this.configDirectory, required this.executable});

  final String configDirectory;
  final String executable;
  File get _file =>
      File(p.join(configDirectory, 'autostart', 'kelivo.desktop'));

  // Exec has both desktop-entry string escaping and argument quoting rules.
  static String quoteExecutable(String value) {
    final quoted = value
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('`', '\\`')
        .replaceAll(r'$', r'\$')
        .replaceAll('%', '%%');
    return '"${quoted.replaceAll('\\', '\\\\').replaceAll('\n', r'\n').replaceAll('\r', r'\r')}"';
  }

  Future<bool> isEnabled() async {
    if (!await _file.exists()) return false;
    final lines = await _file.readAsLines();
    var inEntry = false;
    final values = <String, String>{};
    for (final raw in lines) {
      final line = raw.trim();
      if (line.startsWith('[')) {
        inEntry = line == '[Desktop Entry]';
      } else if (inEntry && !line.startsWith('#')) {
        final split = line.indexOf('=');
        if (split > 0) {
          values[line.substring(0, split)] = line.substring(split + 1);
        }
      }
    }
    return values['Hidden'] != 'true' &&
        values['X-GNOME-Autostart-enabled'] != 'false' &&
        values['Exec'] == '${quoteExecutable(executable)} --autostart';
  }

  Future<void> setEnabled(bool enabled) async {
    final file = _file;
    if (!enabled) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      '[Desktop Entry]\nType=Application\nName=Kelivo\n'
      'Exec=${quoteExecutable(executable)} --autostart\n'
      'Terminal=false\nStartupNotify=false\n',
      flush: true,
    );
    await temporary.rename(file.path);
  }
}
