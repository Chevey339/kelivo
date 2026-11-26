const deepSeekApiBaseUrl = 'https://api.deepseek.com/v1';

Uri deepSeekToolEndpoint(Uri base, String tool) {
  final path = base.path.replaceFirst(RegExp(r'/+$'), '');
  final suffix = '/tools/$tool';
  if (path.endsWith(suffix)) return base.replace(path: path);
  final versionedPath = path.endsWith('/v1') ? path : '$path/v1';
  return base.replace(path: '$versionedPath$suffix');
}
