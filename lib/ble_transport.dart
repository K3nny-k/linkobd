import 'dart:async';
import 'dart:convert'; // For utf8.decode
// For Uint8List
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class BleTransport {
  static const String serviceUuid = "0000fff0-0000-1000-8000-00805f9b34fb";
  static const String notifyCharacteristicUuid = "0000fff1-0000-1000-8000-00805f9b34fb"; // Read/Notify
  static const String writeCharacteristicUuid = "0000fff2-0000-1000-8000-00805f9b34fb"; // Write

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  StreamSubscription<List<int>>? _notifySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  final _rawResponseController = StreamController<String>.broadcast();
  final _rawBytesController = StreamController<Uint8List>.broadcast();
  final _connectionStateController = StreamController<BluetoothConnectionState>.broadcast();
  
  DateTime? _connectionTime;
  bool _firstWriteAfterConnect = true;
  
  Stream<String> get rawResponseStream => _rawResponseController.stream;
  Stream<Uint8List> get rawBytesStream => _rawBytesController.stream;

  Stream<BluetoothConnectionState> get connectionStateStream => _connectionStateController.stream;

  bool get isConnected => _connectedDevice != null && _writeCharacteristic != null;

  Future<void> _ensureConnected() async {
    if (_connectedDevice == null || _writeCharacteristic == null) {
      throw Exception('BLE not connected');
    }
    
    // Check real-time connection state
    try {
      final currentState = await _connectedDevice!.connectionState.first.timeout(const Duration(seconds: 1));
      if (currentState != BluetoothConnectionState.connected) {
        _connectedDevice = null;
        _writeCharacteristic = null;
        _notifyCharacteristic = null;
        _connectionStateController.add(BluetoothConnectionState.disconnected);
        throw Exception('BLE link lost');
      }
    } catch (e) {
      _connectedDevice = null;
      _writeCharacteristic = null;
      _notifyCharacteristic = null;
      _connectionStateController.add(BluetoothConnectionState.disconnected);
      throw Exception('BLE link lost');
    }
  }

  BluetoothDevice? getConnectedDevice() => _connectedDevice;

  void _bindConnectionStream(BluetoothDevice device) {
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = device.connectionState.listen(
      (state) {
        print("🔵 Connection state changed: $state");
        _connectionStateController.add(state);
        
        if (state != BluetoothConnectionState.connected) {
          print("🔵 Device disconnected, cleaning up");
          _connectedDevice = null;
          _writeCharacteristic = null;
          _notifyCharacteristic = null;
          _notifySubscription?.cancel();
          _notifySubscription = null;
          _firstWriteAfterConnect = true;
          _connectionTime = null;
        }
      },
      onError: (error) {
        debugPrint('🔥 Connection state stream error: $error');
        _connectionStateController.addError(error);
      },
      cancelOnError: false,
    );
    
    // Emit initial connected state
    _connectionStateController.add(BluetoothConnectionState.connected);
  }

  // Scan for devices
  Stream<List<ScanResult>> startScan() async* {
    print("🔍 Starting BLE scan for all devices...");
    
    // Check Flutter Blue Plus availability
    try {
      final bluetoothState = await FlutterBluePlus.isSupported;
      print("🔍 Bluetooth supported: $bluetoothState");
      
      if (!bluetoothState) {
        print("❌ Bluetooth is not supported on this device");
        yield [];
        return;
      }
    } catch (e) {
      print("❌ Error checking Bluetooth support: $e");
    }
    
    // Check permissions first
    try {
      print("🔍 Checking permissions...");
      
      // Check location permission (required for BLE scanning)
      final locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        print("🔍 Requesting location permission...");
        final result = await Permission.location.request();
        if (!result.isGranted) {
          print("❌ Location permission denied - BLE scan may not work properly");
        }
      }
      
      // Check Bluetooth scan permission (Android 12+)
      final bluetoothScanStatus = await Permission.bluetoothScan.status;
      if (!bluetoothScanStatus.isGranted) {
        print("🔍 Requesting Bluetooth scan permission...");
        await Permission.bluetoothScan.request();
      }
      
      // Check Bluetooth connect permission (Android 12+)
      final bluetoothConnectStatus = await Permission.bluetoothConnect.status;
      if (!bluetoothConnectStatus.isGranted) {
        print("🔍 Requesting Bluetooth connect permission...");
        await Permission.bluetoothConnect.request();
      }
      
      print("✅ Permission checks completed");
    } catch (e) {
      print("❌ Error checking permissions: $e");
      // Continue anyway - permissions might not be needed on older Android versions
    }
    
    // Check adapter state
    try {
      final adapterState = await FlutterBluePlus.adapterState.first.timeout(const Duration(seconds: 5));
      print("🔍 Bluetooth adapter state: $adapterState");
      
      if (adapterState != BluetoothAdapterState.on) {
        print("❌ Bluetooth adapter is not on: $adapterState");
        if (adapterState == BluetoothAdapterState.off) {
          print("❌ Please turn on Bluetooth in device settings");
        }
        yield [];
        return;
      }
      print("✅ Bluetooth adapter is ON");
    } catch (e) {
      print("❌ Error checking adapter state: $e");
      print("❌ Continuing with scan anyway...");
    }
    
    // Check if already scanning
    try {
      final isScanning = await FlutterBluePlus.isScanning.first;
      if (isScanning) {
        print("🔍 Already scanning, stopping first");
        await FlutterBluePlus.stopScan();
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      print("⚠️ Error checking/stopping previous scan: $e");
    }
    
    try {
      print("🔍 Starting scan for all devices...");
      
      FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );
      print("🔍 ✅ Scan initiated successfully");
      
      // Yield the scan results stream
      yield* FlutterBluePlus.scanResults;
      
    } catch (e, stackTrace) {
      print("❌ Error starting scan: $e");
      print("❌ Stack trace: $stackTrace");
      yield [];
    }
  }

  void stopScan() {
    print("🛑 Stopping BLE scan");
    FlutterBluePlus.stopScan();
    print("🛑 BLE scan stopped");
  }

  // Connect to a device
  Future<bool> connect(BluetoothDevice device) async {
    print("🔵 connect(${device.remoteId}) start");
    
    if (_connectedDevice != null) {
      print("🔵 Disconnecting existing device first");
      await disconnect();
    }
    
    // Try connection with retry logic
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print("🔵 Attempting GATT connection to ${device.remoteId} (attempt $attempt/3)");
        
        // Add a small delay between attempts
        if (attempt > 1) {
          print("🔵 Waiting before retry...");
          await Future.delayed(Duration(milliseconds: 1000 * attempt));
        }
        
        await device.connect(
          autoConnect: false,
          timeout: const Duration(seconds: 15),
        );
        print("🔵 GATT connection established to ${device.remoteId}");
        
        _connectedDevice = device;
        print("🔵 Starting service discovery");
        await _discoverServices();
        
        final success = isConnected;
        if (success) {
          _connectionTime = DateTime.now();
          _firstWriteAfterConnect = true;
          _bindConnectionStream(device);
        }
        print(success ? "✅ connect(${device.remoteId}) success - ready to communicate" : "❌ connect(${device.remoteId}) failed - no suitable characteristics found");
        return success;
      } catch (e, stackTrace) {
        print("❌ connect attempt $attempt failed: $e");
        
        // Clean up on failure
        _connectedDevice = null;
        _writeCharacteristic = null;
        _notifyCharacteristic = null;
        
        // If this is the last attempt, give up
        if (attempt == 3) {
          print("❌ All connection attempts failed");
          print("❌ Final error: $e");
          print("❌ Stack trace: $stackTrace");
          return false;
        } else {
          print("🔄 Will retry connection...");
        }
      }
    }
    
    return false;
  }

  // Discover services and characteristics
  Future<void> _discoverServices() async {
    if (_connectedDevice == null) return;
    
    print("🔵 Discovering services...");
    
    List<BluetoothService> services = [];
    
    try {
      // Try the normal service discovery first
      services = await _connectedDevice!.discoverServices()
          .timeout(const Duration(seconds: 10));
      print("🔵 Normal service discovery succeeded");
    } catch (e) {
      print("⚠️ Normal service discovery failed: $e");
      
      // If normal discovery fails, try to access services directly
      try {
        print("🔵 Trying to access services directly...");
        services = _connectedDevice!.servicesList;
        print("🔵 Got ${services.length} services from servicesList");
      } catch (e2) {
        print("❌ Could not access services: $e2");
        
        // As a last resort, try a minimal approach
        print("🔵 Attempting minimal service discovery...");
        try {
          // Wait a bit for the connection to stabilize
          await Future.delayed(const Duration(milliseconds: 500));
          services = _connectedDevice!.servicesList;
        } catch (e3) {
          print("❌ All service discovery methods failed: $e3");
          return;
        }
      }
    }
    
    print("🔵 Found ${services.length} services");
    for (BluetoothService service in services) {
      print("🔵 Service: ${service.uuid}");
    }
    
    bool foundCustomService = false;
    for (BluetoothService service in services) {
      if (service.uuid == Guid(serviceUuid)) {
        foundCustomService = true;
        print("✅ Found custom service: ${service.uuid}");
        
        print("🔵 Found ${service.characteristics.length} characteristics:");
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          print("🔵 Characteristic: ${characteristic.uuid}, properties: ${characteristic.properties}");
          
          if (characteristic.uuid == Guid(writeCharacteristicUuid)) {
            _writeCharacteristic = characteristic;
            print("✅ Write Characteristic found: ${characteristic.uuid}");
          } else if (characteristic.uuid == Guid(notifyCharacteristicUuid)) {
            _notifyCharacteristic = characteristic;
            print("✅ Notify Characteristic found: ${characteristic.uuid}");
            
            // Try to enable notifications, but don't fail if it doesn't work
            if (characteristic.properties.notify || characteristic.properties.indicate) {
              try {
                print("🔵 Attempting to enable notifications on custom characteristic...");
                await characteristic.setNotifyValue(true)
                    .timeout(const Duration(seconds: 5));
                
                await Future.delayed(const Duration(milliseconds: 200));
                
                _notifySubscription = characteristic.onValueReceived.listen((value) {
                  _rawResponseController.add(utf8.decode(value, allowMalformed: true));
                  _rawBytesController.add(Uint8List.fromList(value));
                });
                print("✅ Successfully subscribed to notify characteristic");
              } catch (e) {
                print("⚠️ Failed to enable notifications (continuing anyway): $e");
                // Don't fail the connection - we can still send commands
              }
            } else {
              print("⚠️ Custom characteristic doesn't support notifications");
            }
          }
        }
        break;
      }
    }
    
    if (!foundCustomService) {
      print("⚠️ Custom service $serviceUuid not found!");
      print("Available services:");
      for (BluetoothService service in services) {
        print("  - ${service.uuid}");
        // Also list characteristics for debugging
        for (BluetoothCharacteristic char in service.characteristics) {
          print("    └─ Char: ${char.uuid} (${char.properties})");
        }
      }
      
      // Try to find Nordic UART service as fallback
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase().contains('6e400001')) {
          print("🔵 Found Nordic UART service: ${service.uuid}");
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            print("🔵 Nordic characteristic: ${characteristic.uuid}");
            
            // Nordic UART TX (write to device)
            if (characteristic.uuid.toString().toLowerCase().contains('6e400002')) {
              _writeCharacteristic = characteristic;
              print("✅ TX Characteristic found: ${characteristic.uuid}");
            }
            // Nordic UART RX (notify from device)  
            else if (characteristic.uuid.toString().toLowerCase().contains('6e400003')) {
              _notifyCharacteristic = characteristic;
              print("✅ RX Characteristic found: ${characteristic.uuid}");
              
              if (characteristic.properties.notify) {
                try {
                  print("🔵 Attempting to enable notifications on Nordic RX...");
                  await characteristic.setNotifyValue(true)
                      .timeout(const Duration(seconds: 5));
                  await Future.delayed(const Duration(milliseconds: 200));
                  _notifySubscription = characteristic.onValueReceived.listen((value) {
                    _rawResponseController.add(utf8.decode(value, allowMalformed: true));
                    _rawBytesController.add(Uint8List.fromList(value));
                  });
                  print("✅ Successfully subscribed to RX characteristic");
                } catch (e) {
                  print("⚠️ Failed to enable RX notifications (continuing anyway): $e");
                }
              }
            }
          }
          break;
        }
      }
      
      // If no Nordic UART, try to find any writable characteristic as a last resort
      if (_writeCharacteristic == null) {
        print("🔍 Looking for any writable characteristic as fallback...");
        for (BluetoothService service in services) {
          for (BluetoothCharacteristic char in service.characteristics) {
            if (char.properties.write || char.properties.writeWithoutResponse) {
              print("🔍 Found writable characteristic: ${char.uuid} in service ${service.uuid}");
              _writeCharacteristic = char;
              print("✅ Using fallback write characteristic: ${char.uuid}");
              break;
            }
          }
          if (_writeCharacteristic != null) break;
        }
      }
    }
    
    // Check if we have at least the write characteristic (minimum for basic functionality)
    if (_writeCharacteristic != null) {
      print("✅ Service discovery completed - write capability available!");
      if (_notifyCharacteristic != null) {
        print("✅ Both write and notify characteristics found!");
      } else {
        print("⚠️ Only write characteristic found (no notifications)");
      }
    } else {
      print("⚠️ No suitable write characteristic found!");
      print("Expected custom service characteristics:");
      print("  - Write: $writeCharacteristicUuid");
      print("  - Notify: $notifyCharacteristicUuid");
    }
  }

  // Send command
  Future<void> sendCommand(String command) async {
    await _ensureConnected();
    
    // Defensive delay for first write after connection
    if (_firstWriteAfterConnect && _connectionTime != null) {
      final elapsed = DateTime.now().difference(_connectionTime!);
      if (elapsed.inMilliseconds < 500) {
        final waitTime = 500 - elapsed.inMilliseconds;
        debugPrint('🔵 First write after connect, waiting ${waitTime}ms for connection to stabilize');
        await Future.delayed(Duration(milliseconds: waitTime));
      }
      _firstWriteAfterConnect = false;
    }
    
    // Ensure command ends with a newline or carriage return if required by your OBD adapter
    // Most ELM327 expect a carriage return.
    List<int> bytes = utf8.encode("$command\r"); 
    await _writeCharacteristic!.write(bytes, withoutResponse: false); // `withoutResponse: false` for acknowledged write
    print("Sent: $command");
  }

  // Send raw bytes with automatic chunking for large frames
  Future<void> sendRawBytes(Uint8List bytes) async {
    await _ensureConnected();
    
    // Defensive delay for first write after connection
    if (_firstWriteAfterConnect && _connectionTime != null) {
      final elapsed = DateTime.now().difference(_connectionTime!);
      if (elapsed.inMilliseconds < 500) {
        final waitTime = 500 - elapsed.inMilliseconds;
        debugPrint('🔵 First write after connect, waiting ${waitTime}ms for connection to stabilize');
        await Future.delayed(Duration(milliseconds: waitTime));
      }
      _firstWriteAfterConnect = false;
    }
    
    // Try long write first, fall back to chunking if it fails
    const int maxChunkSize = 20; // Maximum BLE write size for acknowledged writes without long writes
    
    if (bytes.length <= maxChunkSize) {
      // Single write for small data
      await _writeCharacteristic!.write(bytes, withoutResponse: false);
      final hexString = bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      print("Sent raw bytes: $hexString");
    } else {
      // Try long write first for larger data
      try {
        await _writeCharacteristic!.write(bytes, withoutResponse: false, allowLongWrite: true);
        final hexString = bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        print("Sent raw bytes (long write): $hexString");
      } catch (e) {
        print("Long write failed (${e.toString()}), falling back to chunking");
        
        // Fall back to chunking
        print("Data too large (${bytes.length} bytes), chunking into $maxChunkSize byte pieces");
        
        for (int offset = 0; offset < bytes.length; offset += maxChunkSize) {
          final end = (offset + maxChunkSize < bytes.length) ? offset + maxChunkSize : bytes.length;
          final chunk = bytes.sublist(offset, end);
          
          await _writeCharacteristic!.write(chunk, withoutResponse: false);
          
          final hexString = chunk.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
          print("Sent chunk ${(offset ~/ maxChunkSize) + 1}: $hexString");
          
          // Small delay between chunks to avoid overwhelming the device
          if (end < bytes.length) {
            await Future.delayed(const Duration(milliseconds: 20));
          }
        }
        
        final totalHexString = bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        print("Complete frame sent in ${(bytes.length / maxChunkSize).ceil()} chunks: $totalHexString");
      }
    }
  }

  // Disconnect
  Future<void> disconnect() async {
    print("🔵 Disconnect called");
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    
    // Try to disconnect gracefully
    try {
      await _connectedDevice?.disconnect();
    } catch (e) {
      debugPrint('🔵 Error during device disconnect (may be already disconnected): $e');
    }
    
    _connectedDevice = null;
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _firstWriteAfterConnect = true;
    _connectionTime = null;
    
    _connectionStateController.add(BluetoothConnectionState.disconnected);
    _rawResponseController.addError("Disconnected"); // Signal disconnection
    _rawBytesController.addError("Disconnected"); // Signal disconnection
    print("Disconnected");
  }

  /// Diagnostic method to check BLE connection and notification status
  Future<void> diagnoseBleConnection() async {
    print("🔍 === BLE Connection Diagnosis ===");
    
    // Check basic connection
    print("🔍 Connected device: ${_connectedDevice?.remoteId ?? 'None'}");
    print("🔍 Write characteristic: ${_writeCharacteristic?.uuid ?? 'None'}");
    print("🔍 Notify characteristic: ${_notifyCharacteristic?.uuid ?? 'None'}");
    print("🔍 Notify subscription active: ${_notifySubscription != null}");
    
    if (_connectedDevice == null) {
      print("❌ No device connected");
      return;
    }
    
    if (_notifyCharacteristic == null) {
      print("❌ No notify characteristic found");
      print("🔍 Attempting to re-discover services...");
      
      try {
        print("🔍 Re-discovering services...");
        final services = await _connectedDevice!.discoverServices();
        print("🔍 Found ${services.length} services after re-discovery");
      } catch (e) {
        print("❌ Service re-discovery failed: $e");
      }
      return;
    }
    
    // Check if notifications are actually enabled
    try {
      final isNotifying = _notifyCharacteristic!.isNotifying;
      print("🔍 Notifications enabled: $isNotifying");
      
      if (!isNotifying) {
        print("⚠️ Notifications not enabled, attempting to enable...");
        await _notifyCharacteristic!.setNotifyValue(true);
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Re-setup subscription
        _notifySubscription?.cancel();
        _notifySubscription = _notifyCharacteristic!.onValueReceived.listen((value) {
          final timestamp = DateTime.now().toString().substring(11, 19);
          final hexData = value.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
          print("📥 [$timestamp] Raw notification received: $hexData");
          
          _rawResponseController.add(utf8.decode(value, allowMalformed: true));
          _rawBytesController.add(Uint8List.fromList(value));
        });
        print("✅ Notifications re-enabled and subscription re-established");
      }
    } catch (e) {
      print("❌ Notification check/setup failed: $e");
    }
    
    // Test simple write to see if device responds
    if (_writeCharacteristic != null) {
      print("🔍 Sending test command to device...");
      try {
        // Send a simple test command
        final testData = Uint8List.fromList([0xAA, 0xA6, 0x00, 0x00, 0x02, 0x3E, 0x00, 0x00]);
        await _writeCharacteristic!.write(testData, withoutResponse: false);
        print("✅ Test command sent: ${testData.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ')}");
        print("⏳ Waiting 3 seconds for any response...");
        
        // Wait and see if any data comes back
        await Future.delayed(const Duration(seconds: 3));
        print("🔍 If no 📥 messages appeared above, the device is not responding");
      } catch (e) {
        print("❌ Test command failed: $e");
      }
    }
    
    print("🔍 === End Diagnosis ===");
  }

  void dispose() {
    stopScan();
    disconnect();
    _rawResponseController.close();
    _rawBytesController.close();
    _connectionStateController.close();
  }
} 