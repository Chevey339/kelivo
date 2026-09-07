import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/features/home/services/file_upload_service.dart';
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
      expect(picker.extensions, containsAll(['pdf', 'docx', 'txt']));
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
    },
  );

  test(
    'archives need a workspace; media and cloud-sandbox data keep existing routes',
    () {
      DocumentAttachment file(String name, String mime) =>
          DocumentAttachment(path: '/upload/$name', fileName: name, mime: mime);
      expect(
        FileUploadService.supportsWithoutWorkspace(
          file('app.apk', 'application/octet-stream'),
        ),
        isFalse,
      );
      expect(
        FileUploadService.supportsWithoutWorkspace(
          file('notes.pdf', 'application/pdf'),
        ),
        isTrue,
      );
      expect(
        FileUploadService.supportsWithoutWorkspace(
          file('song.m4a', 'audio/mp4'),
        ),
        isTrue,
      );
      expect(
        FileUploadService.supportsWithoutWorkspace(
          file('data.xlsx', 'application/octet-stream'),
        ),
        isTrue,
      );
    },
  );
}
