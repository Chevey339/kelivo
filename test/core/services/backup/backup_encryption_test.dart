import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/export.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/backup_encryption.dart';
import 'package:Kelivo/core/services/backup/backup_task_progress.dart';

// Independently generated with Node/OpenSSL pbkdf2Sync + aes-256-gcm.
// Salt: 00..0f, nonce prefix: 10..17, AAD: 41-byte header + block index.
const _fixture =
    'S0VMSVZFTkMCAAECAwQFBgcICQoLDA0ODxAREhMUFRYXAAAAAAAAADDfv9sQMhLcGKdBs+O9GOv9+MuXeoLSOUhIh3sqp/OT1ePJ5gwXLAZaLMdjSR/ez4GfRT25MBu1ge4+HpO4y/WM';
const _password = '  口令🔐\u0000 secret  ';

const _chunkSize = 1024 * 1024;

void main() {
  late Directory root;
  late File source;
  late File encrypted;
  late File restored;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo_crypto_test_');
    source = File('${root.path}/source.zip');
    encrypted = File('${root.path}/encrypted.kbackup');
    restored = File('${root.path}/restored.zip');
  });

  tearDown(() => root.delete(recursive: true));

  test('decrypts an independent AES-GCM and PBKDF2 fixture', () async {
    await encrypted.writeAsBytes(base64Decode(_fixture));
    expect(await BackupEncryption.isEncrypted(encrypted), isTrue);
    await BackupEncryption.decryptFile(
      source: encrypted,
      destination: restored,
      password: _password,
    );
    expect(
      await restored.readAsString(),
      'Kelivo encrypted backup\nAPI key and chat content',
    );
  });

  for (final length in [
    0,
    1,
    16,
    17,
    _chunkSize - 1,
    _chunkSize,
    _chunkSize + 1,
    2 * _chunkSize + 17,
  ]) {
    test(
      'round trips $length bytes across cipher and I/O boundaries',
      () async {
        final bytes = List.generate(length, (i) => (i * 31 + 7) % 256);
        await source.writeAsBytes(bytes);
        final phases = <BackupPhase>{};
        await BackupEncryption.encryptFile(
          source: source,
          destination: encrypted,
          password: _password,
          onProgress: (progress) => phases.add(progress.phase),
        );
        final chunks = length == 0
            ? 1
            : (length + _chunkSize - 1) ~/ _chunkSize;
        expect(await encrypted.length(), 41 + length + chunks * 16);
        expect(await BackupEncryption.isEncrypted(source), isFalse);
        await BackupEncryption.decryptFile(
          source: encrypted,
          destination: restored,
          password: _password,
        );
        expect(await restored.readAsBytes(), bytes);
        expect(phases, contains(BackupPhase.encrypting));
      },
    );
  }

  test('each encryption uses a fresh salt and nonce', () async {
    await source.writeAsString('same secret');
    await BackupEncryption.encryptFile(
      source: source,
      destination: encrypted,
      password: _password,
    );
    await BackupEncryption.encryptFile(
      source: source,
      destination: restored,
      password: _password,
    );
    final first = await encrypted.readAsBytes();
    final second = await restored.readAsBytes();
    expect(first.sublist(9, 25), isNot(second.sublist(9, 25)));
    expect(first.sublist(25, 33), isNot(second.sublist(25, 33)));
  });

  for (final mutation in [
    'password',
    'salt',
    'nonce',
    'ciphertext',
    'tag',
    'truncate',
    'append',
  ]) {
    test('$mutation fails authentication and removes plaintext', () async {
      final bytes = base64Decode(_fixture).toList();
      switch (mutation) {
        case 'salt':
          bytes[9] ^= 1;
        case 'nonce':
          bytes[25] ^= 1;
        case 'ciphertext':
          bytes[44] ^= 1;
        case 'tag':
          bytes[bytes.length - 1] ^= 1;
        case 'truncate':
          bytes.removeLast();
        case 'append':
          bytes.add(0);
      }
      await encrypted.writeAsBytes(bytes);
      await expectLater(
        BackupEncryption.decryptFile(
          source: encrypted,
          destination: restored,
          password: mutation == 'password' ? 'wrong' : _password,
        ),
        mutation == 'truncate' || mutation == 'append'
            ? throwsFormatException
            : throwsA(isA<BackupDecryptionException>()),
      );
      expect(await restored.exists(), isFalse);
      expect(await encrypted.readAsBytes(), bytes);
    });
  }

  test(
    'rejects unsupported version and incomplete header before creating output',
    () async {
      for (final bytes in [
        base64Decode(_fixture)..[8] = 1,
        base64Decode(_fixture)..[8] = 3,
        base64Decode(_fixture)..[33] = 0x80,
        base64Decode(_fixture).sublist(0, 20),
      ]) {
        await encrypted.writeAsBytes(bytes);
        await expectLater(
          BackupEncryption.decryptFile(
            source: encrypted,
            destination: restored,
            password: _password,
          ),
          throwsFormatException,
        );
        expect(await restored.exists(), isFalse);
      }
    },
  );

  test(
    'multi-chunk stream matches OpenSSL and rejects reorder and truncation',
    () async {
      final plaintext = Uint8List.fromList(
        List.generate(2 * _chunkSize + 17, (i) => (i * 31 + 7) % 256),
      );
      final header = base64Decode(
        'S0VMSVZFTkMCAAECAwQFBgcICQoLDA0ODxAREhMUFRYXAAAAAAAgABE=',
      );
      final keyHex =
          '8187ee17dd32ce6139b1f78e5fe635ee15c7606fc9dc6fbb2032f166cdefc462';
      final key = Uint8List.fromList([
        for (var i = 0; i < keyHex.length; i += 2)
          int.parse(keyHex.substring(i, i + 2), radix: 16),
      ]);
      final chunks = <Uint8List>[];
      for (var index = 0; index < 3; index++) {
        final nonce = Uint8List(12)..setRange(0, 8, header, 25);
        ByteData.sublistView(nonce).setUint32(8, index, Endian.big);
        final aad = Uint8List(45)..setRange(0, 41, header);
        ByteData.sublistView(aad).setUint32(41, index, Endian.big);
        final cipher = GCMBlockCipher(AESEngine())
          ..init(true, AEADParameters(KeyParameter(key), 128, nonce, aad));
        chunks.add(
          cipher.process(
            Uint8List.sublistView(
              plaintext,
              index * _chunkSize,
              index == 2 ? plaintext.length : (index + 1) * _chunkSize,
            ),
          ),
        );
      }
      final fixture = Uint8List.fromList([
        ...header,
        for (final chunk in chunks) ...chunk,
      ]);
      // Independent Node/OpenSSL digest of the complete three-chunk envelope.
      expect(
        crypto.sha256.convert(fixture).toString(),
        'a5b7058125a1b6a5672389e32c12adf85709043b29579c3af02b467b87f1693d',
      );
      await encrypted.writeAsBytes(fixture);
      await BackupEncryption.decryptFile(
        source: encrypted,
        destination: restored,
        password: _password,
      );
      expect(await restored.readAsBytes(), plaintext);
      await restored.delete();
      final shortHeader = Uint8List.fromList(header);
      ByteData.sublistView(shortHeader).setUint64(33, _chunkSize, Endian.big);
      final corruptLast = Uint8List.fromList(chunks.last)..[0] ^= 1;
      for (final changed in [
        [...header, ...chunks[1], ...chunks[0], ...chunks[2]],
        [...header, ...chunks[0], ...chunks[0], ...chunks[2]],
        [...shortHeader, ...chunks[0]],
        [...header, ...chunks[0], ...chunks[1], ...corruptLast],
      ]) {
        await encrypted.writeAsBytes(changed);
        await expectLater(
          BackupEncryption.decryptFile(
            source: encrypted,
            destination: restored,
            password: _password,
          ),
          throwsA(isA<BackupDecryptionException>()),
        );
        expect(await restored.exists(), isFalse);
      }
    },
  );

  test('cancellation during key derivation never publishes output', () async {
    await source.writeAsString('secret');
    final token = BackupCancelToken();
    addTearDown(token.dispose);
    await expectLater(
      BackupEncryption.encryptFile(
        source: source,
        destination: encrypted,
        password: _password,
        cancelToken: token,
        onProgress: (_) => token.cancel(),
      ),
      throwsA(isA<BackupCancelledException>()),
    );
    expect(await encrypted.exists(), isFalse);
    expect(await source.readAsString(), 'secret');
  });
}
