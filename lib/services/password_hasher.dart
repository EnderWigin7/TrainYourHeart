import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class HashedPassword {
  final String hash;
  final String salt;
  const HashedPassword({required this.hash, required this.salt});
}

class PasswordHasher {
  static final _rng = Random.secure();

  static HashedPassword hash(String plaintext) {
    final saltBytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    final salt = base64.encode(saltBytes);
    return HashedPassword(hash: _hashWith(plaintext, salt), salt: salt);
  }

  static bool verify(String plaintext, String hash, String salt) {
    if (hash.isEmpty || salt.isEmpty) return false;
    return _hashWith(plaintext, salt) == hash;
  }

  static String _hashWith(String plaintext, String salt) {
    final bytes = utf8.encode(salt + plaintext);
    return sha256.convert(bytes).toString();
  }
}
