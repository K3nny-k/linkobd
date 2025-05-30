import 'package:flutter/services.dart';
import 'package:csv/csv.dart';

class EcuInfo {
  final String node;
  final String ecuId;
  final String name;   // us_en
  
  const EcuInfo(this.node, this.ecuId, this.name);
  
  @override
  String toString() => '$name – $ecuId';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EcuInfo &&
          runtimeType == other.runtimeType &&
          node == other.node &&
          ecuId == other.ecuId &&
          name == other.name;

  @override
  int get hashCode => node.hashCode ^ ecuId.hashCode ^ name.hashCode;
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
} 