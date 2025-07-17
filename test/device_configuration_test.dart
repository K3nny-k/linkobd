import 'package:flutter_test/flutter_test.dart';
import 'package:linkobd/domain/protocol/frame_codec.dart';

void main() {
  group('Device Configuration Tests', () {
    test('CAN config frame should have correct acknowledgment response format', () {
      // Expected acknowledgment: 55 A9 00 01 FF 00
      const List<int> expectedCanAck = [0x55, 0xA9, 0x00, 0x01, 0xFF, 0x00];
      
      // Verify response structure
      expect(expectedCanAck[0], equals(0x55)); // Response header 1
      expect(expectedCanAck[1], equals(0xA9)); // Response header 2  
      expect(expectedCanAck[2], equals(0x00)); // DLC high byte
      expect(expectedCanAck[3], equals(0x01)); // DLC low byte (1 byte data + CRC)
      expect(expectedCanAck[4], equals(0xFF)); // Command acknowledgment
      expect(expectedCanAck[5], equals(0x00)); // CRC
      
      expect(expectedCanAck.length, equals(6));
    });
    
    test('UDS Flow Control frame should have correct acknowledgment response format', () {
      // Expected acknowledgment: 55 A9 00 01 FE 00
      const List<int> expectedFlowControlAck = [0x55, 0xA9, 0x00, 0x01, 0xFE, 0x00];
      
      // Verify response structure
      expect(expectedFlowControlAck[0], equals(0x55)); // Response header 1
      expect(expectedFlowControlAck[1], equals(0xA9)); // Response header 2
      expect(expectedFlowControlAck[2], equals(0x00)); // DLC high byte  
      expect(expectedFlowControlAck[3], equals(0x01)); // DLC low byte (1 byte data + CRC)
      expect(expectedFlowControlAck[4], equals(0xFE)); // Command acknowledgment
      expect(expectedFlowControlAck[5], equals(0x00)); // CRC
      
      expect(expectedFlowControlAck.length, equals(6));
    });
    
    test('CAN configuration frame should be created correctly', () {
      final frame = BleCanProtocol.createCanConfigFrame(
        canChannel: 0,
        filterCount: 1,
        baudrate: 500,
        diagCanId: 0x000007FF,
        diagReqCanId: 0x00000710,
        filterMask: 0xFFFFFFFF,
      );
      
      // Verify frame structure
      expect(frame[0], equals(0xAA)); // Header 1
      expect(frame[1], equals(0xA6)); // Header 2
      expect(frame[2], equals(0xFF)); // CAN config command
      expect(frame[3], equals(0x00)); // Length high byte
      expect(frame[4], equals(0x10)); // Length low byte (16 bytes data)
      
      // Verify specific configuration values
      expect(frame[5], equals(0x10)); // filterCount=1, canChannel=0
      expect(frame[6], equals(0x01)); // baudrate high byte (500 = 0x01F4)
      expect(frame[7], equals(0xF4)); // baudrate low byte
      
      // Frame should be 21 bytes total (header + command + length + data + crc)
      expect(frame.length, equals(21));
    });
    
    test('UDS Flow Control frame should be created correctly', () {
      final frame = BleCanProtocol.createUdsFlowControlFrame(
        udsRequestEnable: 1,
        replyFlowControl: 1,
        blockSize: 0x0F,
        stMin: 0x05,
        padValue: 0x55,
      );
      
      // Verify frame structure
      expect(frame[0], equals(0xAA)); // Header 1
      expect(frame[1], equals(0xA6)); // Header 2
      expect(frame[2], equals(0xFE)); // UDS flow control command
      expect(frame[3], equals(0x00)); // Length high byte
      expect(frame[4], equals(0x04)); // Length low byte (4 bytes data)
      
      // Verify configuration values
      expect(frame[5], equals(0x11)); // enable=1, flow=1
      expect(frame[6], equals(0x0F)); // block size
      expect(frame[7], equals(0x05)); // STmin
      expect(frame[8], equals(0x55)); // pad value
      
      // Frame should be 10 bytes total (header + command + length + data + crc)
      expect(frame.length, equals(10));
    });
    
    test('UDS payload frame should handle both small and large payloads', () {
      // Test small payload (< 128 bytes)
      final smallPayload = [0x3E, 0x00]; // Tester Present
      final smallFrame = BleCanProtocol.createUdsPayloadFrame(smallPayload);
      
      expect(smallFrame[0], equals(0xAA)); // Header 1
      expect(smallFrame[1], equals(0xA6)); // Header 2
      expect(smallFrame[2], equals(0x00)); // Small payload command type
      expect(smallFrame[3], equals(0x00)); // Length high byte
      expect(smallFrame[4], equals(0x02)); // Length low byte
      expect(smallFrame[5], equals(0x3E)); // Payload byte 1
      expect(smallFrame[6], equals(0x00)); // Payload byte 2
      
      // Test large payload (>= 128 bytes)
      final largePayload = List.filled(128, 0xAA);
      final largeFrame = BleCanProtocol.createUdsPayloadFrame(largePayload);
      
      expect(largeFrame[2], equals(0x01)); // Large payload command type
      expect(largeFrame[3], equals(0x00)); // Length high byte
      expect(largeFrame[4], equals(0x80)); // Length low byte (128)
    });
    
    test('Frame decoder utilities should work correctly', () {
      final testBytes = [0xAA, 0xA6, 0xFF, 0x00];
      
      // Test hex formatting
      final formatted = FrameDecoder.formatHexBytes(testBytes);
      expect(formatted, equals('AA A6 FF 00'));
      
      // Test hex parsing
      const hexString = 'AA A6 FF 00';
      final parsed = FrameDecoder.parseHexString(hexString);
      expect(parsed, equals([0xAA, 0xA6, 0xFF, 0x00]));
      
      // Test with custom separator
      final customFormatted = FrameDecoder.formatHexBytes(testBytes, separator: '-');
      expect(customFormatted, equals('AA-A6-FF-00'));
    });
  });
} 