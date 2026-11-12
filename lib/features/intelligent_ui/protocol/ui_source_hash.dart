import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../catalog/ui_catalog.dart';

/// The parser supplies normalized source; owner IDs never enter this digest.
String uiSourceHash(String normalizedSource) => sha256
    .convert(utf8.encode('${UiCatalog.version}\n$normalizedSource'))
    .toString();
