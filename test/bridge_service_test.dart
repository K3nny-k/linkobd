import 'package:flutter_test/flutter_test.dart';
import 'package:linkobd/data/bridge/bridge_service.dart';

void main() {
  group('BridgeService Tests', () {
    test('bridge service can be instantiated', () {
      final bridge = BridgeService();
      expect(bridge.isActive, isFalse);
    });

    test('bridge service can be disposed', () {
      final bridge = BridgeService();
      expect(() => bridge.dispose(), returnsNormally);
    });

    test('stop bridge when not active does nothing', () {
      final bridge = BridgeService();
      expect(() => bridge.stopBridge(), returnsNormally);
      expect(bridge.isActive, isFalse);
    });
  });
} 