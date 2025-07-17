import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:csv/csv.dart';
import 'package:linkobd/data/ecu/ecu_repository.dart';

void main() {
  group('EcuRepository Tests', () {
    test('should parse CSV data correctly including new gateway and headunit entries', () {
      // Mock CSV data that includes the new entries
      const csvData = '''Node,ecu_id,us_en
0E,0009,J519 Central Electrics
40,0012,ABS/ESP System
01,0001,Engine Control Module
02,0002,Transmission Control
03,0003,Airbag Control Unit
04,0004,Comfort Control Module
05,0005,Instrument Cluster
06,0006,Headlight Control
07,0007,Steering Wheel Electronics
08,0008,Parking Aid
09,0009,Air Conditioning
0A,000A,Radio/Navigation
0B,000B,Telephone Interface
0C,000C,Adaptive Cruise Control
0D,000D,Lane Change Assistant
0F,000F,Gateway Module
10,0010,Distance Regulation
11,0011,Level Control
12,0012,Tire Pressure Monitor
13,0013,Fuel Pump Control
14,0014,Suspension Electronics
15,0015,Roof Electronics
16,0016,Seat Memory
17,0017,Battery Control Module
18,0018,Auxiliary Heater
19,0019,CAN Gateway
1A,001A,Diagnostic Interface
1B,001B,Digital Sound Package
1C,001C,Suspension Control
1D,001D,Side Assist
1E,001E,Media Player
1F,001F,Special Vehicle Equipment
20,0020,gateway
21,0021,headunit''';

      // Parse the CSV data manually using the same logic as EcuRepository
      final rows = const CsvToListConverter(eol: '\n')
          .convert(csvData, shouldParseNumbers: false)
          .skip(1) // skip header
          .map((row) => EcuInfo(
                row[0]?.toString() ?? '',
                row[1]?.toString() ?? '',
                row[2]?.toString() ?? '',
              ))
          .where((ecu) => ecu.node.isNotEmpty && ecu.ecuId.isNotEmpty && ecu.name.isNotEmpty)
          .toList();

      // Verify that the list is not empty
      expect(rows, isNotEmpty);
      
      // Find the new gateway entry
      final gatewayEcu = rows.where((ecu) => ecu.name == 'gateway').firstOrNull;
      expect(gatewayEcu, isNotNull);
      expect(gatewayEcu!.node, '20');
      expect(gatewayEcu.ecuId, '0020');
      
      // Find the new headunit entry
      final headunitEcu = rows.where((ecu) => ecu.name == 'headunit').firstOrNull;
      expect(headunitEcu, isNotNull);
      expect(headunitEcu!.node, '21');
      expect(headunitEcu.ecuId, '0021');
      
      // Verify that both entries are unique
      expect(gatewayEcu, isNot(same(headunitEcu)));
      
      // Verify that the list contains the expected number of entries (original 32 + 2 new = 34)
      expect(rows.length, 34);
    });
    
    test('should filter ECU list correctly', () {
      // Mock CSV data
      const csvData = '''Node,ecu_id,us_en
0F,000F,Gateway Module
19,0019,CAN Gateway
20,0020,gateway
21,0021,headunit''';

      final rows = const CsvToListConverter(eol: '\n')
          .convert(csvData, shouldParseNumbers: false)
          .skip(1)
          .map((row) => EcuInfo(
                row[0]?.toString() ?? '',
                row[1]?.toString() ?? '',
                row[2]?.toString() ?? '',
              ))
          .where((ecu) => ecu.node.isNotEmpty && ecu.ecuId.isNotEmpty && ecu.name.isNotEmpty)
          .toList();
      
      // Test filtering by name
      final gatewayResults = rows.where((ecu) => ecu.name.toLowerCase().contains('gateway')).toList();
      expect(gatewayResults.length, 3); // "Gateway Module", "CAN Gateway", and "gateway"
      
      final headunitResults = rows.where((ecu) => ecu.name.toLowerCase().contains('headunit')).toList();
      expect(headunitResults.length, 1); // Only "headunit"
      
      // Test filtering by node
      final node20Results = rows.where((ecu) => ecu.node == '20').toList();
      expect(node20Results.length, 1);
      expect(node20Results.first.name, 'gateway');
      
      final node21Results = rows.where((ecu) => ecu.node == '21').toList();
      expect(node21Results.length, 1);
      expect(node21Results.first.name, 'headunit');
    });

    test('should handle EcuInfo equality correctly', () {
      final ecu1 = EcuInfo('20', '0020', 'gateway');
      final ecu2 = EcuInfo('20', '0020', 'gateway');
      final ecu3 = EcuInfo('21', '0021', 'headunit');
      
      expect(ecu1, equals(ecu2));
      expect(ecu1, isNot(equals(ecu3)));
      expect(ecu1.hashCode, equals(ecu2.hashCode));
      expect(ecu1.hashCode, isNot(equals(ecu3.hashCode)));
    });

    test('should handle EcuInfo toString correctly', () {
      final ecu = EcuInfo('20', '0020', 'gateway');
      expect(ecu.toString(), equals('gateway – 0020'));
    });

    test('should filter to only gateway and headunit options', () {
      // Mock CSV data with various ECU types
      const csvData = '''Node,ecu_id,us_en
01,0001,Engine Control Module
02,0002,Transmission Control
0F,000F,Gateway Module
19,0019,CAN Gateway
20,0020,gateway
21,0021,headunit
22,0022,Some Other ECU''';

      final allRows = const CsvToListConverter(eol: '\n')
          .convert(csvData, shouldParseNumbers: false)
          .skip(1)
          .map((row) => EcuInfo(
                row[0]?.toString() ?? '',
                row[1]?.toString() ?? '',
                row[2]?.toString() ?? '',
              ))
          .where((ecu) => ecu.node.isNotEmpty && ecu.ecuId.isNotEmpty && ecu.name.isNotEmpty)
          .toList();

      // Apply the same filter logic as in BluetoothViewModel
      final filteredRows = allRows.where((ecu) => 
        ecu.name == 'gateway' || ecu.name == 'headunit'
      ).toList();

      // Should only contain gateway and headunit
      expect(filteredRows.length, 2);
      
      final gatewayEcu = filteredRows.where((ecu) => ecu.name == 'gateway').firstOrNull;
      expect(gatewayEcu, isNotNull);
      expect(gatewayEcu!.node, '20');
      expect(gatewayEcu.ecuId, '0020');
      
      final headunitEcu = filteredRows.where((ecu) => ecu.name == 'headunit').firstOrNull;
      expect(headunitEcu, isNotNull);
      expect(headunitEcu!.node, '21');
      expect(headunitEcu.ecuId, '0021');
      
      // Verify that other ECUs are filtered out
      final engineEcu = filteredRows.where((ecu) => ecu.name == 'Engine Control Module').firstOrNull;
      expect(engineEcu, isNull);
      
      final gatewayModuleEcu = filteredRows.where((ecu) => ecu.name == 'Gateway Module').firstOrNull;
      expect(gatewayModuleEcu, isNull);
    });

    test('should parse actual CSV format correctly', () {
      // Test with the exact format that might be in the file
      const csvData = '''Node,ecu_id,us_en
0E,0009,J519 Central Electrics
40,0012,ABS/ESP System
01,0001,Engine Control Module
02,0002,Transmission Control
03,0003,Airbag Control Unit
04,0004,Comfort Control Module
05,0005,Instrument Cluster
06,0006,Headlight Control
07,0007,Steering Wheel Electronics
08,0008,Parking Aid
09,0009,Air Conditioning
0A,000A,Radio/Navigation
0B,000B,Telephone Interface
0C,000C,Adaptive Cruise Control
0D,000D,Lane Change Assistant
0F,000F,Gateway Module
10,0010,Distance Regulation
11,0011,Level Control
12,0012,Tire Pressure Monitor
13,0013,Fuel Pump Control
14,0014,Suspension Electronics
15,0015,Roof Electronics
16,0016,Seat Memory
17,0017,Battery Control Module
18,0018,Auxiliary Heater
19,0019,CAN Gateway
1A,001A,Diagnostic Interface
1B,001B,Digital Sound Package
1C,001C,Suspension Control
1D,001D,Side Assist
1E,001E,Media Player
1F,001F,Special Vehicle Equipment
20,0020,gateway
21,0021,headunit''';

      // Parse using the same logic as EcuRepository
      final rows = const CsvToListConverter(eol: '\n')
          .convert(csvData, shouldParseNumbers: false)
          .skip(1) // skip header
          .map((row) => EcuInfo(
                row[0]?.toString() ?? '',
                row[1]?.toString() ?? '',
                row[2]?.toString() ?? '',
              ))
          .where((ecu) => ecu.node.isNotEmpty && ecu.ecuId.isNotEmpty && ecu.name.isNotEmpty)
          .toList();

      // Print all rows for debugging
      print('Total rows parsed: ${rows.length}');
      for (int i = 0; i < rows.length; i++) {
        print('Row $i: ${rows[i].name} (${rows[i].node}, ${rows[i].ecuId})');
      }

      // Check specifically for gateway and headunit
      final gatewayEcu = rows.where((ecu) => ecu.name == 'gateway').firstOrNull;
      final headunitEcu = rows.where((ecu) => ecu.name == 'headunit').firstOrNull;

      print('Gateway ECU found: ${gatewayEcu != null}');
      print('Headunit ECU found: ${headunitEcu != null}');

      expect(gatewayEcu, isNotNull);
      expect(headunitEcu, isNotNull);
      expect(rows.length, 34); // Should have 34 entries total
    });

    testWidgets('should load actual CSV file and show all devices', (WidgetTester tester) async {
      // This test requires Flutter binding to be initialized
      await tester.pumpWidget(Container()); // Initialize Flutter binding
      
      try {
        final ecuList = await EcuRepository.load();
        print('Actual CSV file loaded: ${ecuList.length} entries');
        
        // Print all entries for debugging
        for (int i = 0; i < ecuList.length; i++) {
          print('Entry $i: ${ecuList[i].name} (${ecuList[i].node}, ${ecuList[i].ecuId})');
        }
        
        // Check for gateway and headunit (with potential space issues)
        final gatewayEcu = ecuList.where((ecu) => ecu.name.trim() == 'gateway').firstOrNull;
        final headunitEcu = ecuList.where((ecu) => ecu.name.trim() == 'headunit').firstOrNull;
        
        print('Gateway ECU found in file: ${gatewayEcu != null}');
        print('Headunit ECU found in file: ${headunitEcu != null}');
        
        // Should have all 34 entries
        expect(ecuList.length, 34);
        
        // Should have both gateway and headunit (even with space issues)
        expect(gatewayEcu, isNotNull);
        expect(headunitEcu, isNotNull);
        
      } catch (e) {
        print('Error loading CSV file: $e');
        fail('Failed to load CSV file: $e');
      }
    });
  });
} 