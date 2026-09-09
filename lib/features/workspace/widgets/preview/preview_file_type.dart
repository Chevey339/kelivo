import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/icons/lucide_adapter.dart';

/// Visual identity for a file extension (icon + tint used by the binary card).
class PreviewFileTypeStyle {
  const PreviewFileTypeStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

const Color _pdfRed = Color(0xFFD14D41);
const Color _docBlue = Color(0xFF2B6CB0);
const Color _sheetGreen = Color(0xFF2F855A);
const Color _pptOrange = Color(0xFFDD6B20);
const Color _archiveSlate = Color(0xFF4A5568);
const Color _audioPurple = Color(0xFF6B46C1);
const Color _videoRose = Color(0xFFC53030);
const Color _imageTeal = Color(0xFF2B8A8A);
const Color _codeIndigo = Color(0xFF4C51BF);
const Color _fontAmber = Color(0xFFB7791F);
const Color _execSlate = Color(0xFF2C5282);
const Color _genericGrey = Color(0xFF718096);

const Set<String> kPreviewImageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.bmp',
};

const Set<String> kPreviewCodeExtensions = {
  '.txt',
  '.log',
  '.json',
  '.yaml',
  '.yml',
  '.toml',
  '.ini',
  '.conf',
  '.xml',
  '.py',
  '.js',
  '.mjs',
  '.cjs',
  '.ts',
  '.tsx',
  '.jsx',
  '.dart',
  '.swift',
  '.kt',
  '.kts',
  '.java',
  '.c',
  '.cpp',
  '.cc',
  '.cxx',
  '.h',
  '.hpp',
  '.go',
  '.rs',
  '.rb',
  '.php',
  '.sh',
  '.bash',
  '.zsh',
  '.bashrc',
  '.bash_profile',
  '.zshrc',
  '.zprofile',
  '.profile',
  '.sql',
  '.css',
};

const Set<String> kPreviewArchiveExtensions = {
  '.zip',
  '.tar',
  '.gz',
  '.tgz',
  '.7z',
  '.rar',
  '.bz2',
  '.xz',
  '.zst',
  '.lz',
  '.lzma',
  '.cab',
};

const Set<String> kPreviewAudioExtensions = {
  '.mp3',
  '.wav',
  '.aac',
  '.m4a',
  '.flac',
  '.ogg',
  '.oga',
};

const Set<String> kPreviewVideoExtensions = {
  '.mp4',
  '.mov',
  '.mkv',
  '.webm',
  '.avi',
  '.m4v',
};

const Set<String> kPreviewFontExtensions = {
  '.ttf',
  '.otf',
  '.woff',
  '.woff2',
  '.eot',
  '.pfb',
  '.pfm',
};

const Set<String> kPreviewExecutableExtensions = {
  '.exe',
  '.dll',
  '.so',
  '.dylib',
  '.bin',
  '.app',
  '.msi',
  '.deb',
  '.rpm',
  '.apk',
  '.bat',
  '.cmd',
  '.com',
};

const Set<String> _shellRcBasenames = {
  '.bashrc',
  '.bash_profile',
  '.zshrc',
  '.zprofile',
  '.profile',
  'bashrc',
  'bash_profile',
  'zshrc',
  'zprofile',
  'profile',
};

/// Highlight / header language for [path]. Unknown files are `text`.
String languageForPath(String path) {
  final name = p.basename(path).toLowerCase();
  if (_shellRcBasenames.contains(name)) return 'shell';
  return languageForExtension(p.extension(path));
}

String languageForExtension(String extension) {
  switch (extension.toLowerCase()) {
    case '.js':
    case '.mjs':
    case '.cjs':
    case '.jsx':
      return 'javascript';
    case '.ts':
    case '.tsx':
      return 'typescript';
    case '.py':
      return 'python';
    case '.dart':
      return 'dart';
    case '.swift':
      return 'swift';
    case '.kt':
    case '.kts':
      return 'kotlin';
    case '.java':
      return 'java';
    case '.c':
    case '.h':
      return 'c';
    case '.cpp':
    case '.cc':
    case '.cxx':
    case '.hpp':
      return 'cpp';
    case '.go':
      return 'go';
    case '.rs':
      return 'rust';
    case '.rb':
      return 'ruby';
    case '.php':
      return 'php';
    case '.sh':
    case '.bash':
    case '.zsh':
    case '.bashrc':
    case '.bash_profile':
    case '.zshrc':
    case '.zprofile':
    case '.profile':
      return 'shell';
    case '.sql':
      return 'sql';
    case '.html':
    case '.htm':
    case '.svg':
    case '.xml':
      return 'xml';
    case '.css':
      return 'css';
    case '.json':
      return 'json';
    case '.yaml':
    case '.yml':
      return 'yaml';
    case '.md':
    case '.markdown':
      return 'markdown';
    case '.toml':
      return 'toml';
    case '.ini':
      return 'ini';
    case '.conf':
      return 'conf';
    case '.csv':
      return 'csv';
    case '.tsv':
      return 'tsv';
    default:
      return 'text';
  }
}

/// Maps a display / extension label onto a `flutter_highlight` language.
/// Unsupported names fall back to plaintext (caller highlights silently).
String highlightLanguageFor(String lang) {
  final l = lang.trim().toLowerCase();
  if (l.isEmpty ||
      l == 'text' ||
      l == 'plaintext' ||
      l == 'csv' ||
      l == 'tsv') {
    return 'plaintext';
  }
  switch (l) {
    case 'js':
    case 'javascript':
      return 'javascript';
    case 'ts':
    case 'typescript':
      return 'typescript';
    case 'sh':
    case 'zsh':
    case 'bash':
    case 'shell':
      return 'bash';
    case 'yml':
      return 'yaml';
    case 'py':
    case 'python':
      return 'python';
    case 'rb':
    case 'ruby':
      return 'ruby';
    case 'kt':
    case 'kotlin':
      return 'kotlin';
    case 'html':
      return 'xml';
    case 'md':
    case 'markdown':
      return 'markdown';
    case 'toml':
    case 'conf':
      return 'ini';
    default:
      return l;
  }
}

PreviewFileTypeStyle previewFileTypeStyle(String path) {
  final ext = p.extension(path).toLowerCase();
  switch (ext) {
    case '.pdf':
      return const PreviewFileTypeStyle(icon: Lucide.FileText, color: _pdfRed);
    case '.doc':
    case '.docx':
    case '.rtf':
    case '.odt':
    case '.pages':
      return const PreviewFileTypeStyle(icon: Lucide.FileText, color: _docBlue);
    case '.xls':
    case '.xlsx':
    case '.csv':
    case '.tsv':
    case '.ods':
      return const PreviewFileTypeStyle(
        icon: Lucide.FileSpreadsheet,
        color: _sheetGreen,
      );
    case '.ppt':
    case '.pptx':
    case '.key':
    case '.odp':
      return const PreviewFileTypeStyle(
        icon: Lucide.Presentation,
        color: _pptOrange,
      );
    default:
      break;
  }
  if (kPreviewArchiveExtensions.contains(ext)) {
    return const PreviewFileTypeStyle(
      icon: Lucide.FileArchive,
      color: _archiveSlate,
    );
  }
  if (kPreviewAudioExtensions.contains(ext)) {
    return const PreviewFileTypeStyle(
      icon: Lucide.FileAudio,
      color: _audioPurple,
    );
  }
  if (kPreviewVideoExtensions.contains(ext)) {
    return const PreviewFileTypeStyle(
      icon: Lucide.FileVideo,
      color: _videoRose,
    );
  }
  if (kPreviewFontExtensions.contains(ext)) {
    return const PreviewFileTypeStyle(icon: Lucide.FileType, color: _fontAmber);
  }
  if (kPreviewExecutableExtensions.contains(ext)) {
    return const PreviewFileTypeStyle(
      icon: Lucide.SquareTerminal,
      color: _execSlate,
    );
  }
  if (kPreviewImageExtensions.contains(ext)) {
    return const PreviewFileTypeStyle(
      icon: Lucide.FileImage,
      color: _imageTeal,
    );
  }
  if (kPreviewCodeExtensions.contains(ext) ||
      ext == '.md' ||
      ext == '.markdown' ||
      ext == '.html' ||
      ext == '.htm' ||
      ext == '.svg') {
    return const PreviewFileTypeStyle(
      icon: Lucide.FileCode,
      color: _codeIndigo,
    );
  }
  return const PreviewFileTypeStyle(icon: Lucide.File, color: _genericGrey);
}
