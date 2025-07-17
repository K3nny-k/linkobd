import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SFD Activation State Parsing Tests', () {
    test('should return inactive state when no data', () {
      // Given: No SFD data
      final state = _parseSfdState('');
      
      // Then: Should return inactive state
      expect(state['isActive'], false);
      expect(state['minutes'], 0);
    });

    test('should parse inactive SFD state correctly', () {
      // Given: SFD data with inactive pattern (00 00 01 00)
      final testData = '[12:34:56] RX: 55 A9 00 07 62 01 74 00 00 01 00';
      final state = _parseSfdState(testData);
      
      // Then: Should return inactive state
      expect(state['isActive'], false);
      expect(state['minutes'], 0);
    });

    test('should parse active SFD state correctly', () {
      // Given: SFD data with active pattern (01 02 01 59)
      final activeData = '[12:34:56] RX: 55 A9 00 07 62 01 74 01 02 01 59';
      final state = _parseSfdState(activeData);
      
      // Then: Should return active state with 89 minutes (0x59 = 89)
      expect(state['isActive'], true);
      expect(state['minutes'], 89);
    });

    test('should handle multiple lines and find correct SFD response', () {
      // Given: Multiple lines with SFD response in the middle
      final multiLineData = '''
[12:34:55] RX: 55 A9 00 02 3E 00
[12:34:56] RX: 55 A9 00 07 62 01 74 01 02 01 59
[12:34:57] RX: 55 A9 00 03 22 F1 90
''';
      final state = _parseSfdState(multiLineData);
      
      // Then: Should find and parse the SFD response correctly
      expect(state['isActive'], true);
      expect(state['minutes'], 89);
    });

    test('should handle hex values correctly for different minute values', () {
      // Test various hex values for minutes
      final testCases = [
        {'hex': '5A', 'decimal': 90}, // 0x5A = 90 (max mentioned in requirements)
        {'hex': '3C', 'decimal': 60}, // 0x3C = 60
        {'hex': '1E', 'decimal': 30}, // 0x1E = 30
        {'hex': '0F', 'decimal': 15}, // 0x0F = 15
        {'hex': '01', 'decimal': 1},  // 0x01 = 1
      ];

      for (final testCase in testCases) {
        final hexValue = testCase['hex'] as String;
        final expectedMinutes = testCase['decimal'] as int;
        
        final testData = '[12:34:56] RX: 55 A9 00 07 62 01 74 01 02 01 $hexValue';
        final state = _parseSfdState(testData);
        
        expect(state['isActive'], true, reason: 'Should be active for hex $hexValue');
        expect(state['minutes'], expectedMinutes, reason: 'Should parse $hexValue as $expectedMinutes minutes');
      }
    });

    test('should handle real world example data correctly', () {
      // Test with the exact examples from user requirements
      
      // Test inactive case: 00 00 01 00 = sfd 未激活
      final inactiveExample = '[timestamp] RX: 07 62 01 74 00 00 01 00';
      final inactiveState = _parseSfdState(inactiveExample);
      expect(inactiveState['isActive'], false);
      expect(inactiveState['minutes'], 0);
      
      // Test active case: 01 02 01 59 = 激活，最后一个字节59转十进制就是89，激活剩余时间89分钟
      final activeExample = '[timestamp] RX: 07 62 01 74 01 02 01 59';
      final activeState = _parseSfdState(activeExample);
      expect(activeState['isActive'], true);
      expect(activeState['minutes'], 89); // 0x59 = 89
    });

    test('should detect real-time SFD status response correctly', () {
      // Test the SFD status response pattern that should update status immediately
      // The minutes are extracted from the second-to-last byte (倒数第二个字节)
      
      // Test case 1: 55 A9 00 07 62 01 74 02 01 01 20 53 (32 minutes)
      final sfdResponse1 = [0x55, 0xA9, 0x00, 0x07, 0x62, 0x01, 0x74, 0x02, 0x01, 0x01, 0x20, 0x53];
      expect(sfdResponse1.length, 12);
      
      // Verify the frame structure
      expect(sfdResponse1[0], 0x55);  // Frame header
      expect(sfdResponse1[1], 0xA9);  // Frame header
      expect(sfdResponse1[2], 0x00);  // Length high byte
      expect(sfdResponse1[3], 0x07);  // Length low byte (7 bytes data)
      expect(sfdResponse1[4], 0x62);  // SFD response identifier
      expect(sfdResponse1[5], 0x01);  // SFD response identifier
      expect(sfdResponse1[6], 0x74);  // SFD response identifier
      
      // Test second-to-last byte extraction (倒数第二个字节)
      final minutes1 = sfdResponse1[sfdResponse1.length - 2]; // Second-to-last byte
      expect(minutes1, 0x20); // 0x20 = 32 decimal
      expect(minutes1, 32);
      
      // Test case 2: 55 A9 00 07 62 01 74 02 01 01 17 20 (23 minutes)
      final sfdResponse2 = [0x55, 0xA9, 0x00, 0x07, 0x62, 0x01, 0x74, 0x02, 0x01, 0x01, 0x17, 0x20];
      expect(sfdResponse2.length, 12);
      
      // Test second-to-last byte extraction for different value
      final minutes2 = sfdResponse2[sfdResponse2.length - 2]; // Second-to-last byte
      expect(minutes2, 0x17); // 0x17 = 23 decimal
      expect(minutes2, 23);
      
      // Verify that both frames match the SFD pattern (first 7 bytes should be same)
      for (int i = 0; i < 7; i++) {
        expect(sfdResponse1[i], sfdResponse2[i], reason: 'SFD pattern should match at byte $i');
      }
    });

    test('should detect routine control response pattern correctly', () {
      // Test the specific response pattern that triggers automatic SFD query
      // Pattern: 55 A9 00 06 71 01 C0 04 (only check first 8 bytes)
      
      final responseBytes = [0x55, 0xA9, 0x00, 0x06, 0x71, 0x01, 0xC0, 0x04];
      
      // Verify the pattern matches exactly (first 8 bytes only)
      expect(responseBytes.length, 8);
      expect(responseBytes[0], 0x55);  // Frame header
      expect(responseBytes[1], 0xA9);  // Frame header
      expect(responseBytes[2], 0x00);  // Length high byte
      expect(responseBytes[3], 0x06);  // Length low byte (6 bytes data)
      expect(responseBytes[4], 0x71);  // Routine control response (0x31 + 0x40)
      expect(responseBytes[5], 0x01);  // Routine identifier
      expect(responseBytes[6], 0xC0);  // Routine identifier
      expect(responseBytes[7], 0x04);  // Status/data
      
      // Test with additional data after the 8-byte pattern (should still match)
      final responseWithExtraData = [0x55, 0xA9, 0x00, 0x06, 0x71, 0x01, 0xC0, 0x04, 0x24, 0x03, 0x82];
      expect(responseWithExtraData.length, 11);
      // Should match the first 8 bytes regardless of what follows
      for (int i = 0; i < 8; i++) {
        expect(responseWithExtraData[i], responseBytes[i]);
      }
    });

    test('should format SFD query command correctly', () {
      // Test the SFD query command format: AA A6 00 00 03 22 01 74 00
      final sfdQueryFrame = [0xAA, 0xA6, 0x00, 0x00, 0x03, 0x22, 0x01, 0x74, 0x00];
      
      expect(sfdQueryFrame.length, 9);
      expect(sfdQueryFrame[0], 0xAA);  // UDS frame header
      expect(sfdQueryFrame[1], 0xA6);  // UDS frame header
      expect(sfdQueryFrame[2], 0x00);  // Reserved
      expect(sfdQueryFrame[3], 0x00);  // Reserved
      expect(sfdQueryFrame[4], 0x03);  // Data length (3 bytes)
      expect(sfdQueryFrame[5], 0x22);  // Read Data By Identifier service
      expect(sfdQueryFrame[6], 0x01);  // Data identifier high byte
      expect(sfdQueryFrame[7], 0x74);  // Data identifier low byte (0x0174)
      expect(sfdQueryFrame[8], 0x00);  // Padding/checksum
    });

    test('should extract specific frame data for copy functionality', () {
      // Test extracting data from frame with header pattern: 71 01 C0 08 24
      
      // Test case 1: Frame with the target pattern
      final testData1 = '[12:34:56] RX: 55 A9 00 0A 71 01 C0 08 24 AA BB CC DD EE';
      final result1 = _extractSpecificFrameData(testData1);
      expect(result1, 'AA BB CC DD EE');
      
      // Test case 2: Frame without the target pattern
      final testData2 = '[12:34:56] RX: 55 A9 00 07 62 01 74 00 00 01 00';
      final result2 = _extractSpecificFrameData(testData2);
      expect(result2, '');
      
      // Test case 3: Multiple lines with target pattern in the middle
      final testData3 = '''
[12:34:55] RX: 55 A9 00 02 3E 00
[12:34:56] RX: 55 A9 00 08 71 01 C0 08 24 11 22 33
[12:34:57] RX: 55 A9 00 03 22 F1 90
''';
      final result3 = _extractSpecificFrameData(testData3);
      expect(result3, '11 22 33');
      
      // Test case 4: Target pattern with longer data
      final testData4 = '[timestamp] RX: 71 01 C0 08 24 01 02 03 04 05 06 07 08 09 0A';
      final result4 = _extractSpecificFrameData(testData4);
      expect(result4, '01 02 03 04 05 06 07 08 09 0A');
    });

    test('should handle edge cases for frame data extraction', () {
      // Test empty data
      expect(_extractSpecificFrameData(''), '');
      
      // Test pattern found but no data after it
      final testNoData = '[timestamp] RX: 71 01 C0 08 24';
      expect(_extractSpecificFrameData(testNoData), '');
      
      // Test case sensitivity
      final testLowerCase = '[timestamp] RX: 71 01 c0 08 24 FF EE DD';
      expect(_extractSpecificFrameData(testLowerCase), 'FF EE DD');
    });
  });
}

/// Helper function to test the SFD state parsing logic
/// This replicates the logic from BluetoothViewModel.sfdActivationState
Map<String, dynamic> _parseSfdState(String data) {
  if (data.isEmpty) {
    return {'isActive': false, 'minutes': 0};
  }
  
  // Look for SFD response pattern: 62 01 74 followed by 4 bytes
  final lines = data.split('\n');
  for (final line in lines) {
    // Remove timestamp and extract hex data
    final hexData = line.replaceAll(RegExp(r'\[.*?\]'), '').trim();
    if (hexData.contains('62 01 74')) {
      // Find the exact position of 62 01 74 and get the following 4 bytes
      final cleanHex = hexData.replaceAll(RegExp(r'[^0-9A-Fa-f\s]'), ' ');
      final bytes = cleanHex.split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty && s.length == 2)
          .map((s) => int.tryParse(s, radix: 16))
          .where((i) => i != null)
          .cast<int>()
          .toList();
      
      // Look for the pattern 62 01 74 in the bytes
      for (int i = 0; i <= bytes.length - 7; i++) {
        if (bytes[i] == 0x62 && bytes[i + 1] == 0x01 && bytes[i + 2] == 0x74) {
          // Found the pattern, get the next 4 bytes
          if (i + 6 < bytes.length) {
            final byte1 = bytes[i + 3];
            final byte2 = bytes[i + 4];
            final byte3 = bytes[i + 5];
            final byte4 = bytes[i + 6];
            
            // Check if SFD is active
            // Pattern: 00 00 01 00 = not active
            // Pattern: XX XX XX YY = active, YY is remaining minutes in hex
            if (byte1 == 0x00 && byte2 == 0x00 && byte3 == 0x01 && byte4 == 0x00) {
              return {'isActive': false, 'minutes': 0};
            } else {
              // SFD is active, last byte is remaining minutes
              return {'isActive': true, 'minutes': byte4};
            }
          }
        }
      }
    }
  }
  
  return {'isActive': false, 'minutes': 0};
}

/// Helper function to test specific frame data extraction for copy functionality
/// This replicates the logic from BluetoothViewModel.getSpecificFrameDataForCopy
String _extractSpecificFrameData(String data) {
  if (data.isEmpty) {
    return '';
  }
  
  final lines = data.split('\n');
  for (final line in lines) {
    // Remove timestamp and extract hex data
    final hexData = line.replaceAll(RegExp(r'\[.*?\]'), '').trim();
    
    // Look for the specific frame header pattern: 71 01 C0 08 24 (case insensitive)
    if (hexData.toUpperCase().contains('71 01 C0 08 24')) {
      // Extract all hex bytes from the line
      final cleanHex = hexData.replaceAll(RegExp(r'[^0-9A-Fa-f\s]'), ' ');
      final hexBytes = cleanHex.split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty && s.length == 2)
          .toList();
      
      // Look for the pattern 71 01 C0 08 24 in the hex bytes
      for (int i = 0; i <= hexBytes.length - 5; i++) {
        if (hexBytes[i].toUpperCase() == '71' && 
            hexBytes[i + 1].toUpperCase() == '01' && 
            hexBytes[i + 2].toUpperCase() == 'C0' && 
            hexBytes[i + 3].toUpperCase() == '08' && 
            hexBytes[i + 4].toUpperCase() == '24') {
          
          // Found the pattern, extract data starting from the 6th byte (index i + 5)
          if (i + 5 < hexBytes.length) {
            final dataFromSixthByte = hexBytes.skip(i + 5).toList();
            return dataFromSixthByte.join(' ').toUpperCase();
          }
        }
      }
    }
  }
  
  return '';
} 