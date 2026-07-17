import '../models/chat_input_data.dart';

const String multimodalInternalMediaPathsKey = '_kelivo_media_paths';

bool isImageMime(String mime) => mime.toLowerCase().startsWith('image/');

bool isAudioMime(String mime) => mime.toLowerCase().startsWith('audio/');

bool isVideoMime(String mime) => mime.toLowerCase().startsWith('video/');

const _officeMimePrefixes = [
  'application/msword',
  'application/vnd.ms-powerpoint',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument',
];

bool isOfficeDocumentMime(String mime) {
  final lower = mime.toLowerCase();
  return _officeMimePrefixes.any((p) => lower.startsWith(p));
}

bool isLongCatOmniModelId(String upstreamModelId) {
  final normalized = upstreamModelId.trim().toLowerCase();
  return normalized.startsWith('longcat-flash-omni') ||
      normalized.contains('/longcat-flash-omni');
}

String inferMediaMimeFromSource(String source, {String fallbackMime = ''}) {
  final lower = source.toLowerCase();
  if (lower.startsWith('data:')) {
    final start = lower.indexOf(':');
    final semi = lower.indexOf(';');
    if (start >= 0 && semi > start) {
      return lower.substring(start + 1, semi);
    }
  }
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.pcm16')) return 'audio/pcm16';
  if (lower.endsWith('.pcm')) return 'audio/pcm';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.mpeg') || lower.endsWith('.mpg')) return 'video/mpeg';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.avi')) return 'video/x-msvideo';
  if (lower.endsWith('.mkv')) return 'video/x-matroska';
  if (lower.endsWith('.flv')) return 'video/x-flv';
  if (lower.endsWith('.wmv')) return 'video/x-ms-wmv';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.3gp') || lower.endsWith('.3gpp')) return 'video/3gpp';
  // office documents
  if (lower.endsWith('.doc')) return 'application/msword';
  if (lower.endsWith('.docx')) {
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  }
  if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
  if (lower.endsWith('.pptx')) {
    return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
  }
  if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (lower.endsWith('.xlsx')) {
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }
  return fallbackMime;
}

String resolveMediaAttachmentMime({
  required String explicitMime,
  required String fileName,
  required String path,
}) {
  final normalizedExplicit = explicitMime.trim().toLowerCase();
  if (isImageMime(normalizedExplicit) ||
      isAudioMime(normalizedExplicit) ||
      isVideoMime(normalizedExplicit) ||
      isOfficeDocumentMime(normalizedExplicit)) {
    return normalizedExplicit;
  }

  final byName = inferMediaMimeFromSource(fileName);
  if (byName.isNotEmpty) return byName;

  final byPath = inferMediaMimeFromSource(path);
  if (byPath.isNotEmpty) return byPath;

  return normalizedExplicit;
}

String resolveDocumentAttachmentMime(DocumentAttachment attachment) {
  return resolveMediaAttachmentMime(
    explicitMime: attachment.mime,
    fileName: attachment.fileName,
    path: attachment.path,
  );
}
