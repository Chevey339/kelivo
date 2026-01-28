import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;

import '../../../l10n/app_localizations.dart';
import '../../../shared/dialogs/file_duplicate_dialog.dart';
import '../../../utils/app_directories.dart';
import '../../../utils/file_import_helper.dart';
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
    required BuildContext Function() getContext,
    required this.mediaController,
    required this.onScrollToBottom,
  }) : _getContext = getContext;

  /// 媒体控制器，用于添加图片和文件到输入栏
  final ChatInputBarController mediaController;

  /// Context provider callback to avoid storing stale context
  final BuildContext Function() _getContext;

  /// 滚动到底部的回调
  final VoidCallback onScrollToBottom;

  /// 复制选中的文件到应用上传目录
  ///
  /// [files] 要复制的文件列表
  /// 返回复制后的文件路径列表
  Future<List<String>> copyPickedFiles(List<XFile> files) async {
    final dir = await AppDirectories.getUploadDirectory();
    final out = <String>[];
    final context = _getContext();
    for (final f in files) {
      final savedPath = await FileImportHelper.copyXFile(f, dir, context);
      if (savedPath != null) {
        out.add(savedPath);
      }
    }
    return out;
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
