import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DbKeyStore {
  static const _storageKey = 'urge_surfer_db_key';
  static const _storage = FlutterSecureStorage();

  static Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _storageKey);
    if (existing != null) return existing;

    final rng = Random.secure();
    final bytes = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      bytes[i] = rng.nextInt(256);
    }
    // base64 keeps the value free of SQL metacharacters, so it can be
    // interpolated into PRAGMA key = '...' without escaping.
    final key = base64Encode(bytes);
    await _storage.write(key: _storageKey, value: key);
    return key;
  }
}
