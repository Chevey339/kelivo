import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) => build(args, (input, output) async {
  if (!input.config.buildCodeAssets) return;
  await CBuilder.library(
    name: 'workspace_file',
    assetName: 'core/services/workspace/workspace_file_permissions.dart',
    sources: ['native/workspace_file.c'],
    libraries: [if (input.config.code.targetOS == OS.windows) 'advapi32'],
  ).run(input: input, output: output);
});
