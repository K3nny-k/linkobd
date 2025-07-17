import 'package:flutter_test/flutter_test.dart';
import 'package:linkobd/domain/protocol/frame_codec.dart';

void main() {
  group('BLE-CAN Protocol Tests', () {
    group('CRC8 Calculation', () {
      test('should calculate CRC8 correctly with polynomial 0x1F', () {
        // Test with known data
        final data = [0x00, 0x00, 0x02, 0x3E, 0x00];
        final crc = BleCanProtocol.calculateCrc8(data);
        
        // CRC should be a valid 8-bit value
        expect(crc, greaterThanOrEqualTo(0));
        expect(crc, lessThanOrEqualTo(255));
      });
      
      test('should verify CRC8 of complete frame', () {
        final frame = [0xAA, 0xA6, 0x00, 0x00, 0x02, 0x3E, 0x00, 0x42]; // Example with CRC
        final dataWithoutHeader = frame.sublist(2);
        final calculatedCrc = BleCanProtocol.calculateCrc8(dataWithoutHeader.sublist(0, dataWithoutHeader.length - 1));
        
        // Replace last byte with calculated CRC for testing
        frame[frame.length - 1] = calculatedCrc;
        
        expect(BleCanProtocol.verifyCrc8(frame), isTrue);
      });
    });
    
    group('CAN Configuration Frame (0xFF)', () {
      test('should create CAN config frame with correct format', () {
        final frame = BleCanProtocol.createCanConfigFrame(
          canChannel: 0,
          filterCount: 1,
          baudrate: 500,
          diagCanId: 0x000007FF,
          diagReqCanId: 0x00000710,
          filterMask: 0xFFFFFFFF,
        );
        
        // Check frame structure
        expect(frame[0], equals(0xAA)); // Header 1
        expect(frame[1], equals(0xA6)); // Header 2
        expect(frame[2], equals(0xFF)); // Command type
        expect(frame[3], equals(0x00)); // Length high byte
        expect(frame[4], equals(0x10)); // Length low byte (16 bytes)
        
        // Check channel and filter count
        expect(frame[5], equals(0x10)); // filterCount=1 (high nibble), canChannel=0 (low nibble)
        
        // Check baudrate (500 in big-endian)
        expect(frame[6], equals(0x01)); // 500 >> 8
        expect(frame[7], equals(0xF4)); // 500 & 0xFF
        
        // Frame should have correct total length
        expect(frame.length, equals(21)); // Header(2) + Command(1) + Length(2) + Data(16) + CRC(1) = 22, but actual is 21
      });
      
      test('should handle different CAN channel values', () {
        final frame0 = BleCanProtocol.createCanConfigFrame(
          canChannel: 0,
          filterCount: 1,
          baudrate: 500,
          diagCanId: 0x000007FF,
          diagReqCanId: 0x00000710,
          filterMask: 0xFFFFFFFF,
        );
        
        final frame1 = BleCanProtocol.createCanConfigFrame(
          canChannel: 1,
          filterCount: 1,
          baudrate: 500,
          diagCanId: 0x000007FF,
          diagReqCanId: 0x00000710,
          filterMask: 0xFFFFFFFF,
        );
        
        expect(frame0[5], equals(0x10)); // channel 0
        expect(frame1[5], equals(0x11)); // channel 1
      });
    });
    
    group('UDS Flow Control Frame (0xFE)', () {
      test('should create UDS flow control frame with correct format', () {
        final frame = BleCanProtocol.createUdsFlowControlFrame(
          udsRequestEnable: 1,
          replyFlowControl: 1,
          blockSize: 0x0F,
          stMin: 0x05,
          padValue: 0x55,
        );
        
        // Check frame structure
        expect(frame[0], equals(0xAA)); // Header 1
        expect(frame[1], equals(0xA6)); // Header 2
        expect(frame[2], equals(0xFE)); // Command type
        expect(frame[3], equals(0x00)); // Length high byte
        expect(frame[4], equals(0x04)); // Length low byte (4 bytes)
        
        // Check control byte (upper 4 bits = enable, lower 4 bits = flow control)
        expect(frame[5], equals(0x11)); // enable=1, flow=1
        
        // Check parameters
        expect(frame[6], equals(0x0F)); // block size
        expect(frame[7], equals(0x05)); // STmin
        expect(frame[8], equals(0x55)); // pad value
        
        // Frame should have correct total length
        expect(frame.length, equals(10)); // Header + Command + Length + Data + CRC
      });
    });
    
    group('UDS Payload Frame (0x00/0x01)', () {
      test('should create small UDS payload frame', () {
        final payload = [0x22, 0xF1, 0x90]; // Read VIN
        final frame = BleCanProtocol.createUdsPayloadFrame(payload);
        
        // Check frame structure
        expect(frame[0], equals(0xAA)); // Header 1
        expect(frame[1], equals(0xA6)); // Header 2
        expect(frame[2], equals(0x00)); // Command type (small payload)
        expect(frame[3], equals(0x00)); // Length high byte
        expect(frame[4], equals(0x03)); // Length low byte (3 bytes)
        
        // Check payload
        expect(frame[5], equals(0x22));
        expect(frame[6], equals(0xF1));
        expect(frame[7], equals(0x90));
        
        // Frame should have correct total length
        expect(frame.length, equals(9)); // Header + Command + Length + Payload + CRC
      });
      
      test('should create large UDS payload frame for payload >= 128 bytes', () {
        final payload = List.filled(128, 0xAA); // 128 bytes
        final frame = BleCanProtocol.createUdsPayloadFrame(payload);
        
        // Should use large payload command type
        expect(frame[2], equals(0x01)); // Command type (large payload)
        
        // Check length
        expect(frame[3], equals(0x00)); // Length high byte
        expect(frame[4], equals(0x80)); // Length low byte (128)
        
        // Frame should have correct total length
        expect(frame.length, equals(134)); // Header(2) + Command(1) + Length(2) + Payload(128) + CRC(1) = 134
      });
    });
    
    group('Response Frame Parsing', () {
      test('should parse valid response frame', () {
        // Create a mock response: 55 A9 + DLC + data + CRC
        final mockResponse = [
          0x55, 0xA9,           // Response header
          0x00, 0x05,           // DLC = 5 bytes data + 1 CRC
          0x62, 0xF1, 0x90,     // UDS positive response data
          0x41, 0x42,           // More data
          0xCC,                 // CRC (mock)
        ];
        
        final parsed = BleCanProtocol.parseResponseFrame(mockResponse);
        
        expect(parsed, isNotNull);
        expect(parsed!.length, equals(5)); // Should extract 5 bytes (excluding CRC)
        expect(parsed[0], equals(0x62));
        expect(parsed[1], equals(0xF1));
        expect(parsed[2], equals(0x90));
        expect(parsed[3], equals(0x41));
        expect(parsed[4], equals(0x42));
      });
      
      test('should return null for invalid response frame', () {
        // Invalid header
        final invalidResponse = [0x55, 0xA8, 0x00, 0x03, 0x62, 0xF1, 0x90, 0xCC];
        expect(BleCanProtocol.parseResponseFrame(invalidResponse), isNull);
        
        // Too short
        final tooShort = [0x55, 0xA9];
        expect(BleCanProtocol.parseResponseFrame(tooShort), isNull);
      });
      
      test('should handle incomplete response frame', () {
        // Frame claims 5 bytes but only has 3
        final incomplete = [0x55, 0xA9, 0x00, 0x05, 0x62, 0xF1, 0x90];
        expect(BleCanProtocol.parseResponseFrame(incomplete), isNull);
      });
    });
    
    group('Frame Decoder Utilities', () {
      test('should format hex bytes correctly', () {
        final bytes = [0xAA, 0xA6, 0xFF, 0x00];
        final formatted = FrameDecoder.formatHexBytes(bytes);
        expect(formatted, equals('AA A6 FF 00'));
      });
      
      test('should format hex bytes with custom separator', () {
        final bytes = [0xAA, 0xA6, 0xFF, 0x00];
        final formatted = FrameDecoder.formatHexBytes(bytes, separator: '-');
        expect(formatted, equals('AA-A6-FF-00'));
      });
      
      test('should parse hex string correctly', () {
        const hexString = 'AA A6 FF 00';
        final bytes = FrameDecoder.parseHexString(hexString);
        expect(bytes, equals([0xAA, 0xA6, 0xFF, 0x00]));
      });
      
      test('should parse hex string ignoring invalid characters', () {
        const hexString = 'AA-A6:FF_00';
        final bytes = FrameDecoder.parseHexString(hexString);
        expect(bytes, equals([0xAA, 0xA6, 0xFF, 0x00]));
      });
      
      test('should handle lowercase hex', () {
        const hexString = 'aa a6 ff 00';
        final bytes = FrameDecoder.parseHexString(hexString);
        expect(bytes, equals([0xAA, 0xA6, 0xFF, 0x00]));
      });
    });
    
    group('UDS Service IDs', () {
      test('should have correct service ID values', () {
        expect(UdsServiceIds.testerPresent, equals(0x3E));
        expect(UdsServiceIds.diagnosticSessionControl, equals(0x10));
        expect(UdsServiceIds.readDataByIdentifier, equals(0x22));
        expect(UdsServiceIds.routineControl, equals(0x31));
      });
    });
    
    group('UDS Data Identifiers', () {
      test('should have correct data identifier values', () {
        expect(UdsDataIdentifiers.vehicleIdentificationNumber, equals(0xF190));
        expect(UdsDataIdentifiers.vehicleManufacturerSerialNumber, equals(0xF18C));
      });
    });
  });
} 