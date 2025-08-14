import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../ble_transport.dart';
import '../../l10n/app_localizations.dart';

class ConnectScreen extends StatefulWidget {
  final BleTransport bleTransport;

  const ConnectScreen({super.key, required this.bleTransport});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isScanning = false;
  String? _connectingDeviceId; // Track which device is connecting

  @override
  void initState() {
    super.initState();
    print("📱 ConnectScreen initState");
    _startScan();
  }

  void _startScan() {
    if (_isScanning) {
      print("📱 Scan already running, ignoring");
      return;
    }
    
    print("📱 Starting scan...");
    setState(() {
      _isScanning = true;
      _scanResults = [];
    });

    _scanSubscription?.cancel();
    _scanSubscription = widget.bleTransport.startScan().listen(
      (results) {
        print("📱 Scan results received: ${results.length} devices");
        // Show all devices but prioritize OBD devices
        final filteredResults = results.toList();
        
        // Add detailed device debugging
        print("📱 === DEVICE SCAN RESULTS ===");
        for (int i = 0; i < results.length; i++) {
          final result = results[i];
          final deviceName = _getDeviceName(result);
          print("📱 Device $i: '$deviceName' | ID: ${result.device.remoteId} | RSSI: ${result.rssi}");
        }
        
        // Sort devices: OBD devices first, then others
        filteredResults.sort((a, b) {
          final aName = _getDeviceName(a).toLowerCase();
          final bName = _getDeviceName(b).toLowerCase();
          
          // Expanded OBD device detection
          final aIsObd = _isObdDevice(aName);
          final bIsObd = _isObdDevice(bName);
          
          if (aIsObd && !bIsObd) return -1;
          if (!aIsObd && bIsObd) return 1;
          
          // If both are OBD or both are not OBD, sort by signal strength (RSSI)
          return b.rssi.compareTo(a.rssi);
        });
        
        final obdCount = filteredResults.where((r) => _isObdDevice(_getDeviceName(r).toLowerCase())).length;
        print("📱 After sorting: ${filteredResults.length} total devices, $obdCount OBD devices");
        if (mounted) {
          setState(() {
            _scanResults = filteredResults;
          });
        } else {
          print("📱 Widget not mounted, ignoring scan results");
        }
      },
      onError: (error) {
        print("📱 Scan error: $error");
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Scan error: $error')),
          );
        }
      },
    );

    // Auto-stop scanning after 15 seconds
    Future.delayed(const Duration(seconds: 15), () {
      if (_isScanning && mounted) {
        print("📱 Auto-stopping scan after 15 seconds");
        _stopScan();
      }
    });
  }

  void _stopScan() {
    print("📱 Stopping scan and canceling subscription");
    widget.bleTransport.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
    
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _stopScanQuiet() {
    print("📱 Quietly stopping scan without setState");
    widget.bleTransport.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_connectingDeviceId != null) {
      print("⚠️ Already connecting to a device, ignoring");
      return; // Already connecting to a device
    }

    print("📱 Starting connection to device: ${device.remoteId}");
    
    if (mounted) {
      setState(() {
        _connectingDeviceId = device.remoteId.toString();
      });
    }

    print("📱 Stopping scan before connection");
    _stopScan();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).connecting)),
      );
    }

    try {
      print("📱 Calling bleTransport.connect()");
      bool success = await widget.bleTransport.connect(device);
      print("📱 Connection result: $success");
      
      if (mounted) {
        setState(() {
          _connectingDeviceId = null;
        });

        if (success) {
          print("📱 Connection successful, returning to home");
          // Connection successful - pop back to home with result
          Navigator.pop(context, true); // Pass success result
        } else {
          print("📱 Connection failed, showing error");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).connectionFailed)),
          );
        }
      } else {
        print("📱 Widget not mounted after connection attempt");
      }
    } catch (e, stackTrace) {
      print("📱 Connection exception: $e");
      print("📱 Stack trace: $stackTrace");
      
      if (mounted) {
        setState(() {
          _connectingDeviceId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).connectionFailed}: $e')),
        );
      }
    }
  }

  String _getDeviceName(ScanResult result) {
    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    }
    if (result.advertisementData.advName.isNotEmpty) {
      return result.advertisementData.advName;
    }
    return '(Unknown)';
  }

  /// Check if device name indicates it's an OBD device
  bool _isObdDevice(String deviceName) {
    final name = deviceName.toLowerCase();
    
    // Common OBD device name patterns
    final obdPatterns = [
      'obd',           // Generic OBD
      'obdii',         // OBD-II
      'obd-ii',        // OBD-II with dash
      'obd2',          // OBD2
      'elm327',        // Popular OBD chip
      'elm',           // Short version
      'can',           // CAN bus devices
      'ble_obd',       // BLE OBD devices
      'x_ble_obd',     // Specific pattern user mentioned
      'diagnostic',    // Diagnostic devices
      'scanner',       // Scanner devices
      'auto',          // Auto-related devices
      'car',           // Car-related devices
      'vehicle',       // Vehicle devices
      'torque',        // Torque app compatible
      'ecu',           // ECU devices
      'j1979',         // OBD standard
    ];
    
    // Check if device name contains any OBD-related patterns
    for (final pattern in obdPatterns) {
      if (name.contains(pattern)) {
        print("📱 ✅ OBD device detected: '$deviceName' (matched: '$pattern')");
        return true;
      }
    }
    
    return false;
  }

  @override
  void dispose() {
    print("📱 ConnectScreen disposing");
    _stopScanQuiet();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("📱 ConnectScreen build - scanning: $_isScanning, results: ${_scanResults.length}");
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).connect),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _startScan,
            tooltip: AppLocalizations.of(context).refresh,
          ),
        ],
      ),
      body: _isScanning && _scanResults.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context).scanningForDevices),
                ],
              ),
            )
          : _scanResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(AppLocalizations.of(context).noDevicesFound),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: Text(AppLocalizations.of(context).scanAgain),
                        onPressed: _startScan,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _scanResults.length,
                  itemBuilder: (context, index) {
                    final result = _scanResults[index];
                    final deviceName = _getDeviceName(result);
                    
                    final isObdDevice = _isObdDevice(deviceName);
                    
                    return ListTile(
                      leading: Icon(
                        isObdDevice ? Icons.car_rental : Icons.bluetooth,
                        color: isObdDevice ? Colors.green : Colors.blue,
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(deviceName)),
                          if (isObdDevice) 
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'OBD',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(result.device.remoteId.toString()),
                          Text('RSSI: ${result.rssi} dBm', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                      trailing: _connectingDeviceId == result.device.remoteId.toString()
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      onTap: _connectingDeviceId == null ? () => _connectToDevice(result.device) : null,
                    );
                  },
                ),
    );
  }
} 