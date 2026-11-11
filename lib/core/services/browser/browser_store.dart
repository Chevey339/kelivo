import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../utils/app_directories.dart';

/// One versioned snapshot keeps active-tab and tab-list writes consistent.
class BrowserStore {
  BrowserStore({this._directory});
  Directory? _directory;
  Future<void> _writes = Future.value();

  Future<Directory> get directory async {
    final root = _directory ??= Directory(
      p.join(
        (await (Platform.isWindows
                ? AppDirectories.getAppDataDirectory()
                : getApplicationSupportDirectory()))
            .path,
        'browser',
      ),
    );
    await root.create(recursive: true);
    return root;
  }

  Future<Map<String, dynamic>> read() async {
    final file = File(p.join((await directory).path, 'state.json'));
    if (!await file.exists()) return {};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException('Unsupported browser state');
    }
    return decoded;
  }

  Future<void> write(Map<String, Object?> state) {
    // Encode before queuing: later in-memory edits must not change this write.
    final encoded = jsonEncode({'version': 1, ...state});
    final operation = _writes.then((_) async {
      final target = File(p.join((await directory).path, 'state.json'));
      final temporary = File('${target.path}.tmp');
      await temporary.writeAsString(encoded, flush: true);
      await temporary.rename(target.path);
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }
}
