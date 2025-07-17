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

  group('Frame Splitting Tests', () {
    test('should split small data into single frame', () {
      // Test data smaller than 16 bytes
      final testData = List.generate(10, (i) => i % 256);
      final frames = FrameCodec.splitIntoFrames(testData);
      
      expect(frames.length, equals(1));
      
      final frame = frames[0];
      expect(frame[0], equals(0xAA)); // Header
      expect(frame[1], equals(0xA6)); // Header
      expect(frame[2], equals(1));    // Frame index
      expect(frame[3], equals(0));    // Total length high byte
      expect(frame[4], equals(10));   // Total length low byte
      
      // Check data section (should be padded to 16 bytes)
      final dataStart = 5;
      for (int i = 0; i < 10; i++) {
        expect(frame[dataStart + i], equals(testData[i]));
      }
      
      // Check padding (should be 0xFF)
      for (int i = 10; i < 16; i++) {
        expect(frame[dataStart + i], equals(0xFF));
      }
      
      // Check CRC is present
      expect(frame.length, equals(5 + 16 + 1)); // Header + data + CRC
    });

    test('should split large data into multiple frames', () {
      // Test data larger than 16 bytes
      final testData = List.generate(50, (i) => i % 256);
      final frames = FrameCodec.splitIntoFrames(testData);
      
      expect(frames.length, equals(4)); // ceil(50/16) = 4
      
      // Check frame indices
      expect(frames[0][2], equals(1)); // First frame
      expect(frames[1][2], equals(2)); // Second frame
      expect(frames[2][2], equals(3)); // Third frame
      expect(frames[3][2], equals(4)); // Fourth frame
      
      // Check total length in all frames (should be same)
      for (final frame in frames) {
        expect(frame[3], equals(0));   // High byte (50 = 0x0032)
        expect(frame[4], equals(50));  // Low byte
      }
      
      // Check data distribution
      // Frame 1: bytes 0-15
      final frame1DataStart = 5;
      for (int i = 0; i < 16; i++) {
        expect(frames[0][frame1DataStart + i], equals(testData[i]));
      }
      
      // Frame 2: bytes 16-31  
      final frame2DataStart = 5;
      for (int i = 0; i < 16; i++) {
        expect(frames[1][frame2DataStart + i], equals(testData[16 + i]));
      }
      
      // Frame 3: bytes 32-47
      final frame3DataStart = 5;
      for (int i = 0; i < 16; i++) {
        expect(frames[2][frame3DataStart + i], equals(testData[32 + i]));
      }
      
      // Frame 4: bytes 48-49 + padding
      final frame4DataStart = 5;
      for (int i = 0; i < 2; i++) { // 50 - 48 = 2 bytes
        expect(frames[3][frame4DataStart + i], equals(testData[48 + i]));
      }
      
      // Check padding in last frame
      for (int i = 2; i < 16; i++) {
        expect(frames[3][frame4DataStart + i], equals(0xFF));
      }
    });

    test('should parse hex string and split correctly', () {
      final hexString = '1A2B3C${'00' * 30}'; // 33 bytes
      final frames = FrameCodec.parseHexAndSplitFrames(hexString);
      
      expect(frames.length, equals(3)); // ceil(33/16) = 3
      
      // Check first few bytes are parsed correctly
      expect(frames[0][5], equals(0x1A));
      expect(frames[0][6], equals(0x2B));
      expect(frames[0][7], equals(0x3C));
      expect(frames[0][8], equals(0x00));
    });

    test('should calculate correct CRC for frames', () {
      final testData = [0x01, 0x02, 0x03];
      final frames = FrameCodec.splitIntoFrames(testData);
      
      expect(frames.length, equals(1));
      
      final frame = frames[0];
      final frameWithoutCrc = frame.sublist(0, frame.length - 1);
      final expectedCrc = FrameCodec.calculateDataCrc8(frameWithoutCrc);
      final actualCrc = frame.last;
      
      expect(actualCrc, equals(expectedCrc));
    });

    test('should handle empty data', () {
      expect(() => FrameCodec.splitIntoFrames([]), throwsArgumentError);
    });

    test('should handle invalid hex string', () {
      expect(() => FrameCodec.parseHexAndSplitFrames(''), throwsArgumentError);
      expect(() => FrameCodec.parseHexAndSplitFrames('1'), throwsArgumentError); // Odd length
      expect(() => FrameCodec.parseHexAndSplitFrames('XYZ'), throwsArgumentError); // Invalid hex
    });
  });

  group('UDS Command Frame Tests', () {
    test('should create Tester Present command frame with correct format', () {
      // AA A6 00 00 02 3E 00 00 (short format for standard UDS)
      final udsData = [0x3E, 0x00];
      final frame = FrameCodec.createUdsCommandFrame(udsData);
      
      expect(frame, equals([0xAA, 0xA6, 0x00, 0x00, 0x02, 0x3E, 0x00, 0x00]));
    });

    test('should create Diagnostic Session Control command frame with correct format', () {
      // AA A6 00 00 02 10 03 00 (short format for standard UDS)
      final udsData = [0x10, 0x03];
      final frame = FrameCodec.createUdsCommandFrame(udsData);
      
      expect(frame, equals([0xAA, 0xA6, 0x00, 0x00, 0x02, 0x10, 0x03, 0x00]));
    });

    test('should create Read Data By Identifier command frame with correct format', () {
      // AA A6 00 00 03 22 F1 90 00 (short format for standard UDS)
      final udsData = [0x22, 0xF1, 0x90];
      final frame = FrameCodec.createUdsCommandFrame(udsData);
      
      expect(frame, equals([0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0x90, 0x00]));
    });

    test('should create Read Data By Identifier F18C command frame with correct format', () {
      // AA A6 00 00 03 22 F1 8C 00 (short format for standard UDS)
      final udsData = [0x22, 0xF1, 0x8C];
      final frame = FrameCodec.createUdsCommandFrame(udsData);
      
      expect(frame, equals([0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0xF1, 0x8C, 0x00]));
    });

    test('should create Read Data By Identifier 0174 command frame with correct format', () {
      // AA A6 00 00 03 22 01 74 00 (short format for standard UDS)
      final udsData = [0x22, 0x01, 0x74];
      final frame = FrameCodec.createUdsCommandFrame(udsData);
      
      expect(frame, equals([0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0x01, 0x74, 0x00]));
    });

    test('should handle empty UDS data', () {
      expect(() => FrameCodec.createUdsCommandFrame([]), throwsArgumentError);
    });

    test('should handle various UDS data lengths with correct format', () {
      // Single byte command - AA A6 00 00 01 11 00 (short format)
      final singleByte = FrameCodec.createUdsCommandFrame([0x11]);
      expect(singleByte, equals([0xAA, 0xA6, 0x00, 0x00, 0x01, 0x11, 0x00]));
      
      // Longer command - AA A6 00 00 06 2E F1 90 01 02 03 00 (short format)
      final longCommand = FrameCodec.createUdsCommandFrame([0x2E, 0xF1, 0x90, 0x01, 0x02, 0x03]);
      expect(longCommand, equals([0xAA, 0xA6, 0x00, 0x00, 0x06, 0x2E, 0xF1, 0x90, 0x01, 0x02, 0x03, 0x00]));
    });
  });
} 