import 'dart:convert';
import 'dart:io';

class SimpleXOREncryption {
  static String _generateKey(String text, String key) {
    while (key.length < text.length) {
      key += key;
    }
    return key.substring(0, text.length);
  }

  static String encrypt(String text, String key) {
    key = _generateKey(text, key);
    List<int> encryptedBytes = [];
    for (int i = 0; i < text.length; i++) {
      encryptedBytes.add(text.codeUnitAt(i) ^ key.codeUnitAt(i));
    }
    return base64Encode(encryptedBytes);
  }

  static String decrypt(String encryptedText, String key) {
    List<int> encryptedBytes = base64Decode(encryptedText);
    key = _generateKey(String.fromCharCodes(encryptedBytes), key);
    List<int> decryptedBytes = [];
    for (int i = 0; i < encryptedBytes.length; i++) {
      decryptedBytes.add(encryptedBytes[i] ^ key.codeUnitAt(i));
    }
    return String.fromCharCodes(decryptedBytes);
  }
}
