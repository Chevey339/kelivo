import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;

import '../../../l10n/app_localizations.dart';
import '../../../utils/app_directories.dart';
import '../../../utils/platform_utils.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../core/models/chat_input_data.dart';
import '../widgets/chat_input_bar.dart';

/// 文件选取和上传服务
///
/// 负责处理：
/// - 图片选择 (相册/相机)
/// - 文件选择
/// - 桌面拖放处理
/// - 文件复制到应用目录
class FileUploadService {
  FileUploadService({
    required BuildContext context,
    required this.mediaController,
    required this.onScrollToBottom,
  }) : _context = context;

  /// 媒体控制器，用于添加图片和文件到输入栏
  final ChatInputBarController mediaController;

  /// UI context for duplicate prompt dialogs.
  final BuildContext _context;

  /// 滚动到底部的回调
  final VoidCallback onScrollToBottom;

  /// 复制选中的文件到应用上传目录
  ///
  /// [files] 要复制的文件列表
  /// 返回复制后的文件路径列表
  Future<List<String>> copyPickedFiles(List<XFile> files) async {
    final dir = await AppDirectories.getUploadDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final out = <String>[];
    for (final f in files) {
      try {
        final name = f.name.isNotEmpty ? f.name : DateTime.now().millisecondsSinceEpoch.toString();
        final srcPath = f.path;
        final FileStat? srcStat = srcPath.isNotEmpty
            ? await File(srcPath).stat().catchError((_) => null)
            : null;
        debugPrint('[upload-dup] src name=$name path=$srcPath stat=' 
            '${srcStat == null ? 'null' : 'size=${srcStat.size} mtime=${srcStat.modified.toIso8601String()}'}');
        File dest = File(p.join(dir.path, name));
        if (await dest.exists()) {
          // If same file (modified+size), ask to reuse; else versioned copy.
          final destStat = await dest.stat().catchError((_) => null);
          debugPrint('[upload-dup] dest exists path=${dest.path} stat=' 
              '${destStat == null ? 'null' : 'size=${destStat.size} mtime=${destStat.modified.toIso8601String()}'}');
          final srcModifiedSec = srcStat == null ? null : (srcStat.modified.millisecondsSinceEpoch ~/ 1000);
          final destModifiedSec = destStat == null ? null : (destStat.modified.millisecondsSinceEpoch ~/ 1000);
          final sameSize = srcStat != null && destStat != null && srcStat.size == destStat.size;
          final sameModified = srcModifiedSec != null && destModifiedSec != null && srcModifiedSec == destModifiedSec;
          final same = sameSize && sameModified;
          debugPrint('[upload-dup] compare same=$same sameSize=$sameSize sameModified=$sameModified srcSec=$srcModifiedSec destSec=$destModifiedSec');
          if (same) {
            final useExisting = await _confirmUseExistingFile(name);
            debugPrint('[upload-dup] user decision useExisting=$useExisting');
            if (useExisting) {
              out.add(dest.path);
              continue;
            }
          }
          final base = p.basenameWithoutExtension(name);
          final ext = p.extension(name);
          var counter = 1;
          String candidate;
          do {
            candidate = p.join(dir.path, '$base($counter)$ext');
            counter++;
          } while (await File(candidate).exists());
          dest = File(candidate);
          debugPrint('[upload-dup] versioned dest=${dest.path}');
        }
        await dest.writeAsBytes(await f.readAsBytes());
        debugPrint('[upload-dup] wrote file dest=${dest.path}');
        // Keep modified time to help cache keying.
        if (srcStat != null) {
          try { await dest.setLastModified(srcStat.modified); } catch (_) {}
          debugPrint('[upload-dup] setLastModified dest=${dest.path} mtime=${srcStat.modified.toIso8601String()}');
        }
        out.add(dest.path);
      } catch (_) {}
    }
    return out;
  }

  Future<bool> _confirmUseExistingFile(String fileName) async {
    final l10n = AppLocalizations.of(_context)!;
    final res = await showDialog<bool>(
      context: _context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.fileUploadDuplicateTitle),
        content: Text(l10n.fileUploadDuplicateContent(fileName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.fileUploadDuplicateUseExisting),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.fileUploadDuplicateUploadNew),
          ),
        ],
      ),
    );
    return res == true;
  }

  /// 从相册选取图片
  Future<void> onPickPhotos() async {
    try {
      // On desktop, fall back to FilePicker as image_picker is not supported.
      if (PlatformUtils.isDesktopTarget) {
        final res = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          withData: false,
          type: FileType.custom,
          allowedExtensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'heif'],
        );
        if (res == null || res.files.isEmpty) return;
        final toCopy = <XFile>[];
        for (final f in res.files) {
          if (f.path != null && f.path!.isNotEmpty) {
            toCopy.add(XFile(f.path!));
          }
        }
        if (toCopy.isEmpty) return;
        final paths = await copyPickedFiles(toCopy);
        if (paths.isNotEmpty) {
          mediaController.addImages(paths);
          onScrollToBottom();
        }
        return;
      }

      final picker = ImagePicker();
      final files = await picker.pickMultiImage();
      if (files.isEmpty) return;
      final paths = await copyPickedFiles(files);
      if (paths.isNotEmpty) {
        mediaController.addImages(paths);
        onScrollToBottom();
      }
    } catch (_) {}
  }

  /// 从相机拍照
  ///
  /// [context] 用于显示权限提示和错误消息
  Future<void> onPickCamera(BuildContext context) async {
    try {
      // Proactive permission check on mobile
      if (PlatformUtils.isMobile) {
        var status = await Permission.camera.status;
        // Request if not determined; otherwise guide user
        if (status.isDenied || status.isRestricted) {
          status = await Permission.camera.request();
        }
        if (!status.isGranted) {
          final l10n = AppLocalizations.of(context)!;
          showAppSnackBar(
            context,
            message: l10n.cameraPermissionDeniedMessage,
            type: NotificationType.error,
            duration: const Duration(seconds: 4),
            actionLabel: l10n.openSystemSettings,
            onAction: () {
              try {
                openAppSettings();
              } catch (_) {}
            },
          );
          return;
        }
      }
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.camera);
      if (file == null) return;
      final paths = await copyPickedFiles([file]);
      if (paths.isNotEmpty) {
        mediaController.addImages(paths);
        onScrollToBottom();
      }
    } catch (e) {
      try {
        final l10n = AppLocalizations.of(context)!;
        showAppSnackBar(
          context,
          message: l10n.cameraPermissionDeniedMessage,
          type: NotificationType.error,
          duration: const Duration(seconds: 3),
        );
      } catch (_) {}
    }
  }

  /// 根据文件扩展名推断 MIME 类型
  String inferMimeByExtension(String name) {
    final lower = name.toLowerCase();
    // Video
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mpeg') || lower.endsWith('.mpg')) return 'video/mpeg';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.flv')) return 'video/x-flv';
    if (lower.endsWith('.wmv')) return 'video/x-ms-wmv';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.3gp') || lower.endsWith('.3gpp')) return 'video/3gpp';
    // Documents / text
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.js')) return 'application/javascript';
    if (lower.endsWith('.txt') || lower.endsWith('.md')) return 'text/plain';
    return 'text/plain';
  }

  /// 判断文件是否为图片（根据扩展名）
  bool isImageExtension(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }

  /// 选取文件（图片、视频、文档等）
  Future<void> onPickFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: false,
        type: FileType.custom,
        allowedExtensions: const [
          // images
          'png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'heif',
          // videos
          'mp4', 'avi', 'mkv', 'mov', 'flv', 'wmv', 'mpeg', 'mpg', 'webm', '3gp', '3gpp',
          // docs
          'txt', 'md', 'json', 'js', 'pdf', 'docx', 'html', 'xml', 'py', 'java', 'kt', 'dart', 'ts', 'tsx', 'markdown', 'mdx', 'yml', 'yaml'
        ],
      );
      if (res == null || res.files.isEmpty) return;
      final images = <String>[];
      final docs = <DocumentAttachment>[];

      // Build a flat list preserving order, then map saved -> type
      final toCopy = <XFile>[];
      final kinds = <bool>[]; // true=image, false=document
      final names = <String>[];
      for (final f in res.files) {
        final path = f.path;
        if (path != null && path.isNotEmpty) {
          toCopy.add(XFile(path));
          kinds.add(isImageExtension(f.name));
          names.add(f.name);
        }
      }
      if (toCopy.isEmpty) return;
      final saved = await copyPickedFiles(toCopy);
      for (int i = 0; i < saved.length; i++) {
        final savedPath = saved[i];
        final isImage = kinds[i];
        final savedName = p.basename(savedPath);
        if (isImage) {
          images.add(savedPath);
        } else {
          final mime = inferMimeByExtension(savedName);
          docs.add(DocumentAttachment(path: savedPath, fileName: savedName, mime: mime));
        }
      }
      if (images.isNotEmpty) {
        mediaController.addImages(images);
      }
      if (docs.isNotEmpty) {
        mediaController.addFiles(docs);
      }
      if (images.isNotEmpty || docs.isNotEmpty) {
        onScrollToBottom();
      }
    } catch (_) {}
  }

  /// 处理桌面端拖放的文件 (macOS/Windows/Linux)
  Future<void> onFilesDroppedDesktop(List<XFile> files) async {
    if (files.isEmpty) return;
    try {
      final images = <String>[];
      final docs = <DocumentAttachment>[];
      // Preserve order: copy all, then classify by original names
      final toCopy = <XFile>[];
      final kinds = <bool>[]; // true=image, false=document
      final names = <String>[];
      for (final f in files) {
        final name = (f.name.isNotEmpty ? f.name : (f.path.split(Platform.pathSeparator).last));
        toCopy.add(f);
        kinds.add(isImageExtension(name));
        names.add(name);
      }

      final saved = await copyPickedFiles(toCopy);
      for (int i = 0; i < saved.length; i++) {
        final savedPath = saved[i];
        final isImage = kinds[i];
        final savedName = p.basename(savedPath);
        if (isImage) {
          images.add(savedPath);
        } else {
          final mime = inferMimeByExtension(savedName);
          docs.add(DocumentAttachment(path: savedPath, fileName: savedName, mime: mime));
        }
      }
      if (images.isNotEmpty) mediaController.addImages(images);
      if (docs.isNotEmpty) mediaController.addFiles(docs);
      if (images.isNotEmpty || docs.isNotEmpty) onScrollToBottom();
    } catch (_) {}
  }
}
