import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:linkobd/domain/protocol/frame_codec.dart';

void main() {
  group('FrameCodec Tests', () {
    test('encode and decode "HELLO" example', () {
      // Arrange
      final data = Uint8List.fromList('HELLO'.codeUnits);
      const seq = 42;

      // Act - Encode
      final encoded = FrameCodec.encode(data, seq);

      // Assert - Check frame structure
      expect(encoded.length, equals(7 + data.length)); // Header(2) + Seq(1) + Len(2) + Data(5) + CRC(2)
      expect(encoded[0], equals(0xAA)); // Header byte 1
      expect(encoded[1], equals(0x55)); // Header byte 2
      expect(encoded[2], equals(seq)); // Sequence
      expect(encoded[3], equals(data.length & 0xFF)); // Length low byte
      expect(encoded[4], equals((data.length >> 8) & 0xFF)); // Length high byte

      // Check data portion
      for (int i = 0; i < data.length; i++) {
        expect(encoded[5 + i], equals(data[i]));
      }

      // Act - Decode
      final buffer = ByteQueue();
      buffer.addBytes(encoded);
      final decoded = FrameCodec.tryDecode(buffer);

      // Assert - Verify decoded frame
      expect(decoded, isNotNull);
      expect(decoded!.seq, equals(seq));
      expect(decoded.data.length, equals(data.length));
      expect(decoded.data, equals(data));
      expect(buffer.isEmpty, isTrue); // Buffer should be consumed
    });

    test('encode with maximum payload size', () {
      // Arrange
      final data = Uint8List(FrameCodec.maxPayloadSize);
      for (int i = 0; i < data.length; i++) {
        data[i] = i % 256;
      }
      const seq = 255;

      // Act
      final encoded = FrameCodec.encode(data, seq);

      // Assert
      expect(encoded.length, equals(7 + FrameCodec.maxPayloadSize));
      expect(encoded[2], equals(seq));
      expect(encoded[3], equals(FrameCodec.maxPayloadSize & 0xFF));
      expect(encoded[4], equals((FrameCodec.maxPayloadSize >> 8) & 0xFF));
    });

    test('encode throws on oversized payload', () {
      // Arrange
      final data = Uint8List(FrameCodec.maxPayloadSize + 1);

      // Act & Assert
      expect(() => FrameCodec.encode(data, 0), throwsArgumentError);
    });

    test('decode incomplete frame returns null', () {
      // Arrange
      final buffer = ByteQueue();
      buffer.addBytes([0xAA, 0x55, 0x01]); // Incomplete header

      // Act
      final decoded = FrameCodec.tryDecode(buffer);

      // Assert
      expect(decoded, isNull);
      expect(buffer.length, equals(3)); // Buffer unchanged
    });

    test('decode invalid header consumes one byte', () {
      // Arrange
      final buffer = ByteQueue();
      buffer.addBytes([0xFF, 0xAA, 0x55, 0x01, 0x05, 0x00]); // Invalid start, then valid header

      // Act
      final decoded1 = FrameCodec.tryDecode(buffer);

      // Assert
      expect(decoded1, isNull);
      expect(buffer.length, equals(5)); // One byte consumed
      expect(buffer.peek(2), equals([0xAA, 0x55])); // Valid header now at start
    });

    test('decode corrupted CRC returns null', () {
      // Arrange
      final data = Uint8List.fromList('TEST'.codeUnits);
      final encoded = FrameCodec.encode(data, 10);
      
      // Corrupt the CRC
      encoded[encoded.length - 1] = encoded[encoded.length - 1] ^ 0xFF;
      
      final buffer = ByteQueue();
      buffer.addBytes(encoded);

      // Act
      final decoded = FrameCodec.tryDecode(buffer);

      // Assert
      expect(decoded, isNull);
      expect(buffer.length, equals(encoded.length - 2)); // Header consumed
    });

    test('decode invalid length consumes header', () {
      // Arrange
      final buffer = ByteQueue();
      buffer.addBytes([
        0xAA, 0x55, // Valid header
        0x01, // Seq
        0xFF, 0xFF, // Invalid length (65535 > maxPayloadSize)
      ]);

      // Act
      final decoded = FrameCodec.tryDecode(buffer);

      // Assert
      expect(decoded, isNull);
      expect(buffer.length, equals(3)); // Header consumed
    });

    test('decode multiple frames in buffer', () {
      // Arrange
      final data1 = Uint8List.fromList('FIRST'.codeUnits);
      final data2 = Uint8List.fromList('SECOND'.codeUnits);
      final frame1 = FrameCodec.encode(data1, 1);
      final frame2 = FrameCodec.encode(data2, 2);
      
      final buffer = ByteQueue();
      buffer.addBytes(frame1);
      buffer.addBytes(frame2);

      // Act
      final decoded1 = FrameCodec.tryDecode(buffer);
      final decoded2 = FrameCodec.tryDecode(buffer);

      // Assert
      expect(decoded1, isNotNull);
      expect(decoded1!.seq, equals(1));
      expect(decoded1.data, equals(data1));

      expect(decoded2, isNotNull);
      expect(decoded2!.seq, equals(2));
      expect(decoded2.data, equals(data2));

      expect(buffer.isEmpty, isTrue);
    });

    test('decode fragmented frame', () {
      // Arrange
      final data = Uint8List.fromList('FRAGMENTED'.codeUnits);
      final encoded = FrameCodec.encode(data, 99);
      final buffer = ByteQueue();

      // Add frame in fragments
      buffer.addBytes(encoded.sublist(0, 3)); // Partial header
      expect(FrameCodec.tryDecode(buffer), isNull);

      buffer.addBytes(encoded.sublist(3, 7)); // Complete header + length
      expect(FrameCodec.tryDecode(buffer), isNull);

      buffer.addBytes(encoded.sublist(7)); // Rest of frame
      final decoded = FrameCodec.tryDecode(buffer);

      // Assert
      expect(decoded, isNotNull);
      expect(decoded!.seq, equals(99));
      expect(decoded.data, equals(data));
    });

    test('sequence number rollover', () {
      // Arrange
      final data = Uint8List.fromList('ROLLOVER'.codeUnits);

      // Act
      final frame255 = FrameCodec.encode(data, 255);
      final frame0 = FrameCodec.encode(data, 0);

      // Assert
      expect(frame255[2], equals(255));
      expect(frame0[2], equals(0));

      // Decode both
      final buffer = ByteQueue();
      buffer.addBytes(frame255);
      buffer.addBytes(frame0);

      final decoded255 = FrameCodec.tryDecode(buffer);
      final decoded0 = FrameCodec.tryDecode(buffer);

      expect(decoded255!.seq, equals(255));
      expect(decoded0!.seq, equals(0));
    });

    test('empty payload', () {
      // Arrange
      final data = Uint8List(0);
      const seq = 123;

      // Act
      final encoded = FrameCodec.encode(data, seq);
      final buffer = ByteQueue();
      buffer.addBytes(encoded);
      final decoded = FrameCodec.tryDecode(buffer);

      // Assert
      expect(decoded, isNotNull);
      expect(decoded!.seq, equals(seq));
      expect(decoded.data.length, equals(0));
      expect(encoded.length, equals(7)); // Just header + seq + len + crc
    });

    test('CRC16-CCITT calculation', () {
      // Test known CRC values for verification
      final testData = Uint8List.fromList([0x01, 0x02, 0x03]);
      final encoded = FrameCodec.encode(testData, 42);
      
      // The CRC should be consistent
      final encoded2 = FrameCodec.encode(testData, 42);
      expect(encoded, equals(encoded2));
      
      // Different data should produce different CRC
      final testData2 = Uint8List.fromList([0x01, 0x02, 0x04]);
      final encoded3 = FrameCodec.encode(testData2, 42);
      expect(encoded, isNot(equals(encoded3)));
    });
  });

  group('ByteQueue Tests', () {
    test('basic operations', () {
      final queue = ByteQueue();
      expect(queue.isEmpty, isTrue);
      expect(queue.length, equals(0));

      queue.addBytes([1, 2, 3]);
      expect(queue.length, equals(3));
      expect(queue.peek(2), equals([1, 2]));
      expect(queue.length, equals(3)); // Peek doesn't consume

      queue.consume(1);
      expect(queue.length, equals(2));
      expect(queue.peek(2), equals([2, 3]));

      queue.consume(10); // Consume more than available
      expect(queue.isEmpty, isTrue);
    });

    test('peek beyond available data', () {
      final queue = ByteQueue();
      queue.addBytes([1, 2]);
      expect(queue.peek(5), equals([]));
    });
  });
} 