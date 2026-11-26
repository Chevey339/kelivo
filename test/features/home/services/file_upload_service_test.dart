import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';
import 'package:Kelivo/features/home/services/file_upload_service.dart';
import 'package:Kelivo/features/home/services/composer_document_route.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

class _Picker extends FilePicker {
  FileType? type;
  List<String>? extensions;
  bool? buffered;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    this.type = type;
    extensions = allowedExtensions;
    buffered = withData;
    return null;
  }
}

void main() {
  test(
    'picker follows workspace binding without enabling byte buffering',
    () async {
      final picker = _Picker();
      FilePicker.platform = picker;
      var bound = false;
      final service = FileUploadService(
        getContext: () => throw StateError('Cancelled picker needs no UI'),
        mediaController: ChatInputBarController(),
        isImageCropperEnabled: () => false,
        getImageCompressConfig: () => throw StateError('No images selected'),
        hasWorkspace: () => bound,
      );
      await service.onPickFiles();
      expect(picker.type, FileType.custom);
      expect(
        picker.extensions,
        containsAll([
          'pdf',
          'docx',
          'txt',
          'm4a',
          'aac',
          'flac',
          'ogg',
          'opus',
          'aiff',
        ]),
      );
      expect(picker.extensions, isNot(contains('apk')));
      bound = true;
      await service.onPickFiles();
      expect(picker.type, FileType.any);
      expect(picker.extensions, isNull);
      expect(picker.buffered, isFalse);
      expect(
        service.inferMimeByExtension('Dockerfile'),
        'application/octet-stream',
      );
      expect(service.inferMimeByExtension('Voice.M4A'), 'audio/mp4');
      expect(service.inferMimeByExtension('recording.flac'), 'audio/flac');
      expect(
        resolveDocumentAttachmentMime(
          const DocumentAttachment(
            path: '/upload/opaque',
            fileName: 'Voice.M4A',
            mime: 'application/octet-stream',
          ),
        ),
        'audio/mp4',
      );
      expect(
        inferMediaMimeFromSource(
          'https://example.com/voice.m4a?token=redacted',
        ),
        'audio/mp4',
      );
    },
  );

  test(
    'regular chats inspect unknown file contents; only delivered files bypass inspection',
    () {
      DocumentAttachment file(String name) => DocumentAttachment(
        path: '/upload/$name',
        fileName: name,
        mime: 'application/octet-stream',
      );
      for (final name in ['app.apk', 'report.pdf', 'draft.log', 'data.xlsx']) {
        expect(regularDocumentRoute.needsLocalText(file(name)), isTrue);
      }
      expect(regularDocumentRoute.needsLocalText(file('song.m4a')), isFalse);
      const hosted = (
        workspaceBound: false,
        workspaceFiles: false,
        nativePdf: true,
        sandboxData: true,
      );
      expect(hosted.needsLocalText(file('report.pdf')), isFalse);
      expect(hosted.needsLocalText(file('data.xlsx')), isFalse);
      expect(hosted.needsLocalText(file('notes.txt')), isTrue);
      const workspace = (
        workspaceBound: true,
        workspaceFiles: true,
        nativePdf: false,
        sandboxData: false,
      );
      expect(workspace.needsLocalText(file('app.apk')), isFalse);
    },
  );
}
