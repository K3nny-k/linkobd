import 'package:flutter/services.dart';
import 'package:csv/csv.dart';

class EcuInfo {
  final String node;
  final String ecuId;
  final String name;   // us_en
  final int? canPhysReqId;    // CAN Physical Request ID
  final int? canRespUsdtId;   // CAN Response USDT ID
  
  const EcuInfo(this.node, this.ecuId, this.name, {this.canPhysReqId, this.canRespUsdtId});
  
  @override
  String toString() => '$name – $ecuId';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EcuInfo &&
          runtimeType == other.runtimeType &&
          node == other.node &&
          ecuId == other.ecuId &&
          name == other.name &&
          canPhysReqId == other.canPhysReqId &&
          canRespUsdtId == other.canRespUsdtId;

  @override
  int get hashCode => node.hashCode ^ ecuId.hashCode ^ name.hashCode ^ 
                     (canPhysReqId?.hashCode ?? 0) ^ (canRespUsdtId?.hashCode ?? 0);
  
  /// Get the appropriate filter mask based on the response ID
  int get filterMask {
    if (canRespUsdtId == null) return 0xFFFFFFFF;
    return canRespUsdtId! <= 0x7FF ? 0x7FF : 0x1FFFFFFF;
  }
  
  /// Check if this ECU has valid CAN IDs for configuration
  bool get hasValidCanIds => canPhysReqId != null && canRespUsdtId != null;
}

class EcuRepository {
  static Future<List<EcuInfo>> load() async {
    try {
      final csv = await rootBundle.loadString('assets/ECU_List__Key_Fields_.csv');
      return const CsvToListConverter(eol: '\n')
          .convert(csv, shouldParseNumbers: false)
          .skip(1) // skip header
          .map((row) => EcuInfo(
                row[0]?.toString() ?? '',
                row[1]?.toString() ?? '',
                row[2]?.toString() ?? '',
              ))
          .where((ecu) => ecu.node.isNotEmpty && ecu.ecuId.isNotEmpty && ecu.name.isNotEmpty)
          .toList();
    } catch (e) {
      // Return empty list if CSV loading fails
      return [];
    }
  }
  
  /// Load ECU information from XML file with CAN IDs
  static Future<List<EcuInfo>> loadFromXml() async {
    // This would parse the XML file similar to your Python script
    // For now, we'll create a method that generates ECU info with CAN IDs
    // based on the XML structure you showed
    
    // Placeholder implementation - in a real app, you'd parse the XML file
    return _generateEcuListWithCanIds();
  }
  
  /// Generate ECU list with CAN IDs based on XML structure
  static List<EcuInfo> _generateEcuListWithCanIds() {
    // Extracted from ECU_List(1).xml
    return [
      EcuInfo('0C', '0016', 'Steering Column Electronics', canPhysReqId: 0x0000070C, canRespUsdtId: 0x00000776),
      EcuInfo('0E', '0009', 'J519 Central Electrics', canPhysReqId: 0x0000070E, canRespUsdtId: 0x00000778),
      EcuInfo('10', '0019', 'Gateway', canPhysReqId: 0x00000710, canRespUsdtId: 0x0000077A),
      EcuInfo('12', '0044', 'Steering Assistance', canPhysReqId: 0x00000712, canRespUsdtId: 0x0000077C),
      EcuInfo('13', '0003', 'J104 Brakes 1', canPhysReqId: 0x00000713, canRespUsdtId: 0x0000077D),
      EcuInfo('14', '0017', 'Dash Board', canPhysReqId: 0x00000714, canRespUsdtId: 0x0000077E),
      EcuInfo('15', '0015', 'Airbag', canPhysReqId: 0x00000715, canRespUsdtId: 0x0000077F),
      EcuInfo('23', '006D', 'Deck Lid Control Unit', canPhysReqId: 0x00000723, canRespUsdtId: 0x0000078D),
      EcuInfo('31', '002B', 'Steering Column Locking', canPhysReqId: 0x00000731, canRespUsdtId: 0x0000079B),
      EcuInfo('3E', '00BB', 'Door Electronics Rear Driver Side', canPhysReqId: 0x0000073E, canRespUsdtId: 0x000007A8),
      EcuInfo('3F', '00BC', 'Door Electronics Rear Passenger Side', canPhysReqId: 0x0000073F, canRespUsdtId: 0x000007A9),
      EcuInfo('42', '00C5', 'Thermal Management', canPhysReqId: 0x00000742, canRespUsdtId: 0x000007AC),
      EcuInfo('44', '00C6', 'Battery Charger Control Module', canPhysReqId: 0x00000744, canRespUsdtId: 0x000007AE),
      EcuInfo('49', '00A7', 'Infotainment Interface', canPhysReqId: 0x00000749, canRespUsdtId: 0x000007B3),
      EcuInfo('4A', '0042', 'Door Electronics Driver Side', canPhysReqId: 0x0000074A, canRespUsdtId: 0x000007B4),
      EcuInfo('4B', '0052', 'Door Electronics Passenger Side', canPhysReqId: 0x0000074B, canRespUsdtId: 0x000007B5),
      EcuInfo('4C', '0036', 'Seat Adjustment Driver Side', canPhysReqId: 0x0000074C, canRespUsdtId: 0x000007B6),
      EcuInfo('4E', '003C', 'Lane Change Assistant', canPhysReqId: 0x0000074E, canRespUsdtId: 0x000007B8),
      EcuInfo('4F', '00A5', 'Front Sensors Driver Assistance System', canPhysReqId: 0x0000074F, canRespUsdtId: 0x000007B9),
      EcuInfo('53', '0081', 'Gear Shift Control Module', canPhysReqId: 0x00000753, canRespUsdtId: 0x000007BD),
      EcuInfo('57', '0013', 'Adaptive Cruise Control', canPhysReqId: 0x00000757, canRespUsdtId: 0x000007C1),
      EcuInfo('64', '00C0', 'Actuator For Exterior Noise', canPhysReqId: 0x00000764, canRespUsdtId: 0x000007CE),
      EcuInfo('67', '0075', 'Telematics Communication Unit', canPhysReqId: 0x00000767, canRespUsdtId: 0x000007D1),
      EcuInfo('6F', '0047', 'Sound System', canPhysReqId: 0x0000076F, canRespUsdtId: 0x000007D9),
      EcuInfo('73', '005F', 'Information Control Unit 1', canPhysReqId: 0x00000773, canRespUsdtId: 0x000007DD),
      EcuInfo('76', '0001', 'Engine Control Module 1', canPhysReqId: 0x000007E0, canRespUsdtId: 0x000007E8),
      EcuInfo('7B', '008C', 'Battery Energy Control Module', canPhysReqId: 0x17FC007B, canRespUsdtId: 0x17FE007B),
      EcuInfo('7C', '0051', 'Drive Motor Control Module', canPhysReqId: 0x17FC007C, canRespUsdtId: 0x17FE007C),
      EcuInfo('80', '0074', 'Chassis Control', canPhysReqId: 0x17FC0080, canRespUsdtId: 0x17FE0080),
      EcuInfo('84', '00CA', 'Control Module For Sunroof', canPhysReqId: 0x17FC0084, canRespUsdtId: 0x17FE0084),
      EcuInfo('8A', '00CF', 'Control Unit Lane Change Assistant 2', canPhysReqId: 0x17FC008A, canRespUsdtId: 0x17FE008A),
      EcuInfo('8B', '0046', 'Central Module Comfort System', canPhysReqId: 0x17FC008B, canRespUsdtId: 0x17FE008B),
      EcuInfo('96', '00D6', 'Light Control Left 2', canPhysReqId: 0x17FC0096, canRespUsdtId: 0x17FE0096),
      EcuInfo('97', '00D7', 'Light Control Right 2', canPhysReqId: 0x17FC0097, canRespUsdtId: 0x17FE0097),
      EcuInfo('9D', '00DB', 'Front Corner Radar 1', canPhysReqId: 0x17FC009D, canRespUsdtId: 0x17FE009D),
      EcuInfo('9E', '00DC', 'Front Corner Radar 2', canPhysReqId: 0x17FC009E, canRespUsdtId: 0x17FE009E),
      EcuInfo('B7', '8104', 'DC/DC Converter Control Module', canPhysReqId: 0x17FC00B7, canRespUsdtId: 0x17FE00B7),
      EcuInfo('B8', '00CE', 'Drive Motor Control Module 2', canPhysReqId: 0x17FC00B8, canRespUsdtId: 0x17FE00B8),
    ];
  }
} 