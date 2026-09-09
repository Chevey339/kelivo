import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class SkillsKeys {
  static const empty = ValueKey<String>('skills-empty');
  static const list = ValueKey<String>('skills-list');
  static const search = ValueKey<String>('skills-search');
  static const import = ValueKey<String>('skills-import');
  static const importPaste = ValueKey<String>('skills-import-paste');
  static const importFile = ValueKey<String>('skills-import-file');
  static const importGitHub = ValueKey<String>('skills-import-github');
  static const importSubmit = ValueKey<String>('skills-import-submit');
  static const importError = ValueKey<String>('skills-import-error');
  static const delete = ValueKey<String>('skills-detail-delete');
  static const browse = ValueKey<String>('skills-detail-browse');
  static const edit = ValueKey<String>('skills-detail-edit');
  static const export = ValueKey<String>('skills-detail-export');
  static const more = ValueKey<String>('skills-detail-more');
  static const bodyEmpty = ValueKey<String>('skills-detail-body-empty');
  static const actions = ValueKey<String>('skills-detail-actions');
  static const emptyCtas = ValueKey<String>('skills-empty-ctas');
  static const editSave = ValueKey<String>('skills-edit-save');
  static const useAll = ValueKey<String>('skills-assistant-use-all');
  static const openPage = ValueKey<String>('skills-assistant-open-page');
  static const inherit = ValueKey<String>('skills-conversation-inherit');

  static Key item(String id) => ValueKey<String>('skills-item-$id');

  static Key enable(String id) => ValueKey<String>('skills-enable-$id');

  static Key check(String id) => ValueKey<String>('skills-check-$id');

  static Key conversationSkill(String id) =>
      ValueKey<String>('skills-conversation-skill-$id');
}

String skillErrorMessage(Object error) {
  if (error is FormatException) {
    final message = error.message;
    if (message.isNotEmpty) return message;
  }
  return error.toString();
}

/// Brand mark from [assetPath]. Tints with [color] (or [IconTheme]).
class GitHubGlyph extends StatelessWidget {
  const GitHubGlyph({super.key, this.size, this.color});

  static const assetPath = 'assets/icons/github.svg';

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final resolvedSize = size ?? theme.size ?? 24;
    final resolvedColor = color ?? theme.color ?? const Color(0xFF000000);
    return SvgPicture.asset(
      assetPath,
      width: resolvedSize,
      height: resolvedSize,
      colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
    );
  }
}
