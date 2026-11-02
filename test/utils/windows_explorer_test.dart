import 'package:Kelivo/utils/windows_explorer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opens managed workspace directories with Windows separators', () {
    expect(
      windowsExplorerArguments(
        r'C:\Users\Alice\AppData\Roaming\Kelivo/workspaces/workspace-id/files',
        isDirectory: true,
      ),
      [r'C:\Users\Alice\AppData\Roaming\Kelivo\workspaces\workspace-id\files'],
    );
  });

  test('passes directories containing spaces and Unicode as one argument', () {
    expect(
      windowsExplorerArguments(r'D:/My Work/中文资料\项目/', isDirectory: true),
      [r'D:\My Work\中文资料\项目'],
    );
  });

  test('selects preview files with a separate normalized path argument', () {
    expect(
      windowsExplorerArguments(
        r'C:\Users\Alice Smith\Kelivo/workspaces/id/files/报告 1.txt',
        isDirectory: false,
      ),
      ['/select,', r'C:\Users\Alice Smith\Kelivo\workspaces\id\files\报告 1.txt'],
    );
  });

  test('preserves native paths and drive roots', () {
    for (final path in [r'C:\', r'D:\Linked Workspace\中文']) {
      expect(windowsExplorerArguments(path, isDirectory: true), [path]);
    }
    expect(
      windowsExplorerArguments(r'D:\files\report.txt', isDirectory: false),
      ['/select,', r'D:\files\report.txt'],
    );
  });

  test('preserves UNC roots when normalizing directory and file paths', () {
    expect(
      windowsExplorerArguments(
        r'\\server\Shared Work/中文/files',
        isDirectory: true,
      ),
      [r'\\server\Shared Work\中文\files'],
    );
    expect(
      windowsExplorerArguments(
        r'\\server\Shared Work/中文/报告.txt',
        isDirectory: false,
      ),
      ['/select,', r'\\server\Shared Work\中文\报告.txt'],
    );
  });
}
