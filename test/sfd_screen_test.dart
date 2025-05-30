import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

// Helper function to test sanitizeHex logic
Uint8List? sanitizeHex(String text) {
  // 1. Remove labels before any colon
  text = text.replaceAllMapped(RegExp(r'.*?:'), (_) => '');
  // 2. Strip all non-hex chars
  final hex = text.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (hex.isEmpty || hex.length.isOdd) return null;
  final bytes = Uint8List(hex.length ~/ 2);
  for (int i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

void main() {
  group('SFD Screen Sanitizer Tests', () {
    test('sanitizeHex handles simple hex string', () {
      final result = sanitizeHex('7F2182');
      expect(result, isNotNull);
      expect(result?.length, equals(3));
      expect(result, equals([0x7F, 0x21, 0x82]));
    });

    test('sanitizeHex handles hex with spaces', () {
      final result = sanitizeHex('7F 21 82');
      expect(result, isNotNull);
      expect(result?.length, equals(3));
      expect(result, equals([0x7F, 0x21, 0x82]));
    });

    test('sanitizeHex handles multi-line payload with labels', () {
      const payload = '''
SFDREQUESTSTRUCTURE_RQ:
65367334060D2B06100401990A8D11
SFD2_TOKEN_RS:
7F21822020E7
''';
      final result = sanitizeHex(payload);
      expect(result, isNotNull);
      expect(result?.length, equals(21)); // 42 hex chars = 21 bytes
      expect(result?.sublist(0, 4), equals([0x65, 0x36, 0x73, 0x34]));
      expect(result?.sublist(15, 21), equals([0x7F, 0x21, 0x82, 0x20, 0x20, 0xE7]));
    });

    test('sanitizeHex handles large payload', () {
      const largePayload = '''
SFDREQUESTSTRUCTURE_RQ:
65367334060D2B06100401990A8D1165367334060D2B06100401990A8D1165367334060D2B06100401990A8D11
SFD2_TOKEN_RS:
7F21822020E77F21822020E77F21822020E77F21822020E7
''';
      final result = sanitizeHex(largePayload);
      expect(result, isNotNull);
      expect(result?.length, equals(69)); // 138 hex chars = 69 bytes
      expect(result?.sublist(0, 4), equals([0x65, 0x36, 0x73, 0x34]));
    });

    test('sanitizeHex returns null for empty input', () {
      final result = sanitizeHex('');
      expect(result, isNull);
    });

    test('sanitizeHex returns null for odd length hex', () {
      final result = sanitizeHex('7F218');
      expect(result, isNull);
    });

    test('sanitizeHex returns null for non-hex characters only', () {
      final result = sanitizeHex('LABEL_ONLY:');
      expect(result, isNull);
    });

    test('sanitizeHex handles mixed case hex', () {
      final result = sanitizeHex('7f21aB');
      expect(result, isNotNull);
      expect(result?.length, equals(3));
      expect(result, equals([0x7F, 0x21, 0xAB]));
    });

    test('sanitizeHex handles newlines and tabs', () {
      final result = sanitizeHex('7F\n21\t82');
      expect(result, isNotNull);
      expect(result?.length, equals(3));
      expect(result, equals([0x7F, 0x21, 0x82]));
    });
  });
} 