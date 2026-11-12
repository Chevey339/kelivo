import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'backup_cancel_token.dart';
import 'backup_isolate_runner.dart';
import 'backup_task_progress.dart';

typedef BackupPasswordPrompt = Future<String?> Function({required bool retry});

final class BackupDecryptionException implements Exception {
  const BackupDecryptionException();

  @override
  String toString() => 'backup_decryption_failed';
}

/// KELIVENC (8 bytes), version (1), salt (16), nonce prefix (8),
/// plaintext length (8, big endian), followed by 1 MiB AES-256-GCM chunks.
/// Each chunk has a 16-byte tag; even an empty file has one authenticated chunk.
/// New archives use version 3: Argon2id v1.3, 19 MiB, 2 passes, 1 lane,
/// and a 32-byte key. Version 2 remains readable using PBKDF2-HMAC-SHA256
/// (600000 iterations, 32-byte key), as shipped in Kelivo 1.3.2.
/// KDF costs are fixed by the format version, never taken from untrusted input.
/// Nonces are prefix || uint32_be(index); AAD is header || uint32_be(index).
/// Binding the total length and index prevents truncation and reordering.
/// Version 1 was an unreleased whole-file stream and is deliberately rejected.
abstract final class BackupEncryption {
  static const extension = 'kbackup';
  static final _magic = ascii.encode('KELIVENC');
  static const _headerLength = 41;
  static const _chunkSize = 1024 * 1024;
  static const _maxPlaintextBytes = 16 * 1024 * 1024 * 1024;

  static Future<bool> isEncrypted(File file) async {
    final input = await file.open();
    try {
      final prefix = await input.read(_magic.length);
      return _hasMagic(prefix);
    } finally {
      await input.close();
    }
  }

  static bool _hasMagic(List<int> bytes) {
    if (bytes.length < _magic.length) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }

  /// The destination must be in a private temporary directory. Callers own
  /// cleanup after cancellation, using the worker's exit signal before deletion.
  /// Decrypted output must never be consumed until this future succeeds.
  static Future<void> encryptFile({
    required File source,
    required File destination,
    required String password,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) =>
      _transform(source, destination, password, true, onProgress, cancelToken);

  static Future<void> decryptFile({
    required File source,
    required File destination,
    required String password,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) =>
      _transform(source, destination, password, false, onProgress, cancelToken);

  static Future<void> _transform(
    File source,
    File destination,
    String password,
    bool encrypt,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  ) {
    if (password.isEmpty) throw ArgumentError('backup_password_empty');
    if (source.absolute.path == destination.absolute.path) {
      throw ArgumentError('backup_encryption_same_file');
    }
    return runBackupIsolate<void, _EncryptionArgs>(
      body: _transformInIsolate,
      payload: (
        source: source.path,
        destination: destination.path,
        password: password,
        encrypt: encrypt,
      ),
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  static void _transformInIsolate(
    BackupIsolateContext ctx,
    _EncryptionArgs args,
  ) {
    ctx.throwIfCancelled();
    final phase = args.encrypt
        ? BackupPhase.encrypting
        : BackupPhase.decrypting;
    ctx.reportProgress(BackupProgress(phase: phase, processed: 0));
    final input = File(args.source).openSync();
    RandomAccessFile? output;
    Uint8List? key;
    final password = Uint8List.fromList(utf8.encode(args.password));
    var complete = false;
    try {
      final inputLength = input.lengthSync();
      late final Uint8List header;
      late final int plaintextLength;
      if (args.encrypt) {
        plaintextLength = inputLength;
        if (plaintextLength > _maxPlaintextBytes) {
          throw const FormatException('backup_encryption_size');
        }
        final random = Random.secure();
        header = Uint8List(_headerLength)
          ..setRange(0, _magic.length, _magic)
          ..[8] = 3
          ..setRange(9, 33, List.generate(24, (_) => random.nextInt(256)));
        ByteData.sublistView(header).setUint64(33, plaintextLength, Endian.big);
      } else {
        header = _readExactly(input, _headerLength);
        if (!_hasMagic(header)) {
          throw const FormatException('backup_encryption_header');
        }
        if (header[8] != 2 && header[8] != 3) {
          throw const FormatException('backup_encryption_version');
        }
        plaintextLength = ByteData.sublistView(
          header,
        ).getUint64(33, Endian.big);
        if (plaintextLength < 0 || plaintextLength > _maxPlaintextBytes) {
          throw const FormatException('backup_encryption_size');
        }
      }
      final chunks = max(1, (plaintextLength + _chunkSize - 1) ~/ _chunkSize);
      if (!args.encrypt &&
          inputLength != _headerLength + plaintextLength + chunks * 16) {
        throw const FormatException('backup_encryption_size');
      }
      key = _deriveKey(password, header.sublist(9, 25), header[8]);
      ctx.throwIfCancelled();
      output = File(args.destination).openSync(mode: FileMode.write);
      if (args.encrypt) output.writeFromSync(header);
      var processed = 0;
      for (var index = 0; index < chunks; index++) {
        ctx.throwIfCancelled();
        final nonce = Uint8List(12)..setRange(0, 8, header, 25);
        ByteData.sublistView(nonce).setUint32(8, index, Endian.big);
        final aad = Uint8List(_headerLength + 4)
          ..setRange(0, _headerLength, header);
        ByteData.sublistView(aad).setUint32(_headerLength, index, Endian.big);
        final cipher = GCMBlockCipher(AESEngine())
          ..init(
            args.encrypt,
            AEADParameters(KeyParameter(key), 128, nonce, aad),
          );
        final count = min(_chunkSize, plaintextLength - processed);
        final chunk = _readExactly(input, count + (args.encrypt ? 0 : 16));
        // Bound memory and each GCM invocation to one chunk. In particular,
        // PointyCastle 4's GCM length block truncates lengths at 512 MiB.
        // process() authenticates a decrypted chunk before we write any of it.
        output.writeFromSync(cipher.process(chunk));
        processed += count;
        ctx.reportProgress(
          BackupProgress(
            phase: phase,
            processed: processed,
            total: plaintextLength,
            unit: BackupProgressUnit.bytes,
          ),
        );
      }
      if (input.readByteSync() != -1) {
        throw const FormatException('backup_encryption_size');
      }
      ctx.throwIfCancelled();
      complete = true;
    } on InvalidCipherTextException {
      throw const BackupDecryptionException();
    } finally {
      password.fillRange(0, password.length, 0);
      key?.fillRange(0, key.length, 0);
      input.closeSync();
      output?.closeSync();
      if (!complete && output != null) File(args.destination).deleteSync();
    }
  }

  // Keep the Argon2 workspace local to derivation so it is not retained during
  // archive processing. The whole operation runs on the cancellable worker.
  static Uint8List _deriveKey(Uint8List password, Uint8List salt, int version) {
    if (version == 2) {
      final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
        ..init(Pbkdf2Parameters(salt, 600000, 32));
      return kdf.process(password);
    }
    final kdf = Argon2BytesGenerator()
      ..init(
        Argon2Parameters(
          Argon2Parameters.ARGON2_id,
          salt,
          desiredKeyLength: 32,
          memory: 19 * 1024, // KiB, not bytes.
          iterations: 2,
          lanes: 1,
          version: Argon2Parameters.ARGON2_VERSION_13,
        ),
      );
    return kdf.process(password);
  }

  static Uint8List _readExactly(RandomAccessFile input, int length) {
    final bytes = Uint8List(length);
    var offset = 0;
    while (offset < length) {
      final count = input.readIntoSync(bytes, offset);
      if (count == 0) throw const FormatException('backup_encryption_size');
      offset += count;
    }
    return bytes;
  }
}

typedef _EncryptionArgs = ({
  String source,
  String destination,
  String password,
  bool encrypt,
});
