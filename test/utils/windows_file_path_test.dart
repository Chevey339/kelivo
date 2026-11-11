import 'package:Kelivo/utils/windows_file_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extends local drive paths without a Windows host', () {
    expect(
      extendedWindowsFilePath(r'C:\Users\Alice\data.db'),
      r'\\?\C:\Users\Alice\data.db',
    );
    expect(
      extendedWindowsFilePath('D:/My Data/中文/../data.db'),
      r'\\?\D:\My Data\data.db',
    );
    final path = 'D:\\${List.filled(50, 'directory').join('\\')}\\data.db';
    expect(path.length, greaterThan(260));
    expect(extendedWindowsFilePath(path), r'\\?\' + path);
  });

  test('extends UNC shares and preserves already namespaced paths', () {
    expect(
      extendedWindowsFilePath(r'\\server\share\folder\data.db'),
      r'\\?\UNC\server\share\folder\data.db',
    );
    expect(extendedWindowsFilePath(r'\\?\D:\data\file'), r'\\?\D:\data\file');
    expect(
      extendedWindowsFilePath(r'\\?\UNC\server\share\file'),
      r'\\?\UNC\server\share\file',
    );
    expect(extendedWindowsFilePath(r'\\.\C:\data\file'), r'\\.\C:\data\file');
  });

  test('rejects paths relative to the current drive or working directory', () {
    for (final path in [
      r'folder\file',
      r'C:folder\file',
      r'\folder\file',
      '',
    ]) {
      expect(() => extendedWindowsFilePath(path), throwsArgumentError);
    }
  });
}
