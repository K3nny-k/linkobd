import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../ble_transport.dart';
import '../../data/ecu/ecu_repository.dart';

class BluetoothViewModel extends ChangeNotifier {
  final BleTransport _bleTransport;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<Uint8List>? _sfdDataSubscription;
  bool _isConnected = false;
  final List<int> _sfdBuffer = [];
  int? _negotiatedMtu;
  List<EcuInfo> ecuList = [];
  EcuInfo? selectedEcu;

  BluetoothViewModel(this._bleTransport) {
    _isConnected = _bleTransport.isConnected; // initial snapshot
    debugPrint('🔍 BluetoothViewModel created, initial isConnected=$_isConnected');
    _setupConnectionListener();
    _setupSfdDataListener();
  }

  bool get isConnected {
    debugPrint('🔍 isConnected getter -> $_isConnected');
    return _isConnected;
  }

  String get sfdReceivedData {
    if (_sfdBuffer.isEmpty) return '';
    return _sfdBuffer.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
  }

  void _setupConnectionListener() {
    _connectionStateSubscription = _bleTransport.connectionStateStream.listen((state) {
      final wasConnected = _isConnected;
      _isConnected = (state == BluetoothConnectionState.connected);
      
      if (wasConnected != _isConnected) {
        debugPrint('BluetoothViewModel: Connection state changed to $_isConnected');
        if (!_isConnected) {
          _sfdBuffer.clear();
          _negotiatedMtu = null;
          selectedEcu = null;
          ecuList.clear();
        }
        notifyListeners();
      }
    });
  }

  void _setupSfdDataListener() {
    _sfdDataSubscription = _bleTransport.rawBytesStream.listen((data) {
      _sfdBuffer.addAll(data);
      debugPrint('🔍 SFD data received: ${data.length} bytes');
      notifyListeners();
    });
  }

  void clearSfdBuffer() {
    _sfdBuffer.clear();
    notifyListeners();
  }

  Future<void> initEcuList() async {
    try {
      ecuList = await EcuRepository.load();
      debugPrint('🔍 Loaded ${ecuList.length} ECU entries');
      notifyListeners();
    } catch (e) {
      debugPrint('🔥 Failed to load ECU list: $e');
      ecuList = [];
    }
  }

  void selectEcu(EcuInfo? ecu) {
    selectedEcu = ecu;
    debugPrint('🔍 Selected ECU: ${ecu?.toString() ?? 'None'}');
    notifyListeners();
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _sfdDataSubscription?.cancel();
    super.dispose();
  }

  Future<void> _ensureConnected() async {
    if (!_isConnected) {
      throw Exception('BLE not connected');
    }
    
    // Double-check with transport
    if (!_bleTransport.isConnected) {
      _isConnected = false;
      notifyListeners();
      throw Exception('BLE link lost');
    }
  }

  Future<void> requestSfdInfo() async {
    await _ensureConnected();
    
    // Clear buffer before requesting new data
    _sfdBuffer.clear();
    notifyListeners();
    
    // Send SFD request command - this is a placeholder implementation
    // You may need to adjust the command based on your device's protocol
    await _bleTransport.sendCommand('SFD_REQUEST');
    
    // The response will be received via the rawBytesStream listener
  }

  Future<void> sendSfdData(Uint8List bytes) async {
    await _ensureConnected();
    
    // Get or negotiate MTU
    if (_negotiatedMtu == null && _bleTransport.getConnectedDevice() != null) {
      try {
        // Try to request larger MTU
        final device = _bleTransport.getConnectedDevice()!;
        _negotiatedMtu = await device.requestMtu(247);
        debugPrint('🔍 MTU negotiated: $_negotiatedMtu');
      } catch (e) {
        debugPrint('🔍 MTU negotiation failed, using default: $e');
        _negotiatedMtu = 23; // Default BLE MTU
      }
    }
    
    final mtu = _negotiatedMtu ?? 23;
    final chunkSize = mtu - 3; // Reserve 3 bytes for BLE overhead
    
    debugPrint('🔍 Sending ${bytes.length} bytes in chunks of $chunkSize');
    
    // Send data in chunks
    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      // Re-check connection before each chunk
      await _ensureConnected();
      
      final end = min(offset + chunkSize, bytes.length);
      final chunk = bytes.sublist(offset, end);
      
      // Send raw bytes directly
      await _bleTransport.sendRawBytes(chunk);
      
      // Small delay between chunks to avoid overwhelming the device
      if (offset + chunkSize < bytes.length) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      debugPrint('🔍 BluetoothViewModel.connect() starting for ${device.remoteId}');
      
      // Disconnect any existing connection first
      if (_isConnected) {
        debugPrint('🔍 Disconnecting existing connection first');
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 200)); // Brief delay
      }
      
      // Connect via transport
      final success = await _bleTransport.connect(device);
      
      if (success) {
        debugPrint('🔍 Connection successful, waiting for state to stabilize');
        // Give the connection time to stabilize
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Update our local state
        _isConnected = true;
        
        // Initialize ECU list after successful connection
        await initEcuList();
        
        notifyListeners();
      }
      
      return success;
    } catch (e, stack) {
      debugPrint('🔥 BluetoothViewModel.connect() error: $e');
      debugPrint('🔥 Stack: $stack');
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    try {
      debugPrint('🔍 BluetoothViewModel.disconnect() called');
      await _bleTransport.disconnect();
      _isConnected = false;
      _sfdBuffer.clear();
      _negotiatedMtu = null;
      selectedEcu = null;
      ecuList.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('🔥 Error during disconnect: $e');
    }
  }
} 