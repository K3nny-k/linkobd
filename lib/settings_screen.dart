import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ble_transport.dart';

class SettingsScreen extends StatefulWidget {
  final BleTransport bleTransport;

  const SettingsScreen({super.key, required this.bleTransport});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isScanning = false;
  String _statusMessage = "Tap 'Scan' to find devices.";
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    bool granted = await _requestPermissions(showAlert: false);
    if (mounted) {
      setState(() {
        _permissionsGranted = granted;
        if (!_permissionsGranted) {
          _statusMessage = "Bluetooth/Location permissions needed to scan.";
        }
      });
    }
  }

  Future<bool> _requestPermissions({bool showAlert = true}) async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    bool allGranted = true;
    String deniedPermissionsMessage = "Required permissions denied: ";

    if (statuses[Permission.location] != PermissionStatus.granted) {
      allGranted = false;
      deniedPermissionsMessage += "Location, ";
      print("Location permission denied");
    }
    if (statuses[Permission.bluetoothScan] != PermissionStatus.granted) {
      allGranted = false;
      deniedPermissionsMessage += "Bluetooth Scan, ";
      print("Bluetooth Scan permission denied");
    }
    if (statuses[Permission.bluetoothConnect] != PermissionStatus.granted) {
      allGranted = false;
      deniedPermissionsMessage += "Bluetooth Connect, ";
      print("Bluetooth Connect permission denied");
    }

    if (!allGranted && showAlert && mounted) {
        _showPermissionDeniedDialog(deniedPermissionsMessage.substring(0, deniedPermissionsMessage.length - 2));
    }
    return allGranted;
  }

  void _showPermissionDeniedDialog(String message) {
    showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
            title: const Text("Permissions Required"),
            content: Text("$message. Please enable them in app settings."),
            actions: <Widget>[
                TextButton(
                    child: const Text("Open Settings"),
                    onPressed: () {
                        openAppSettings();
                        Navigator.of(context).pop();
                    },
                ),
                TextButton(
                    child: const Text("Cancel"),
                    onPressed: () => Navigator.of(context).pop(),
                ),
            ],
        ),
    );
  }

  void _startScan() async {
    if (!mounted) return;

    if (!_permissionsGranted) {
      _permissionsGranted = await _requestPermissions();
    }

    if (!_permissionsGranted) {
      if (mounted) {
        setState(() {
          _statusMessage = "Permissions not granted. Cannot scan.";
        });
      }
      print("Scan aborted: Permissions not granted.");
      return;
    }

    bool isLocationServiceEnabled = await Permission.location.serviceStatus.isEnabled;
    if (!isLocationServiceEnabled && mounted) {
        showDialog(
            context: context,
            builder: (BuildContext context) => AlertDialog(
                title: const Text("Location Services Disabled"),
                content: const Text("Please enable Location Services (GPS) for Bluetooth scanning to work."),
                actions: <Widget>[
                    TextButton(
                        child: const Text("OK"),
                        onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
            ),
        );
        setState(() {
            _statusMessage = "Location Services are disabled.";
        });
        return;
    }

    setState(() {
      _isScanning = true;
      _scanResults = [];
      _statusMessage = "Scanning for devices...";
    });

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        print("DEBUG: Found ${results.length} BLE devices");
        for (var result in results) {
          print("DEBUG DEVICE: Name='${result.device.platformName}' AdvName='${result.advertisementData.advName}' ID=${result.device.remoteId} RSSI=${result.rssi}");
          print("DEBUG SERVICES: ${result.advertisementData.serviceUuids.map((uuid) => uuid.toString()).join(', ')}");
        }
        
        // Show all devices but prioritize OBD devices
        final filteredResults = results.toList();
        
        // Sort devices: OBD devices first, then others
        filteredResults.sort((a, b) {
          final aName = a.device.platformName.isNotEmpty ? a.device.platformName : a.advertisementData.advName;
          final bName = b.device.platformName.isNotEmpty ? b.device.platformName : b.advertisementData.advName;
          final aIsObd = _isObdDevice(aName);
          final bIsObd = _isObdDevice(bName);
          
          if (aIsObd && !bIsObd) return -1;
          if (!aIsObd && bIsObd) return 1;
          
          // If both are OBD or both are not OBD, sort by signal strength (RSSI)
          return b.rssi.compareTo(a.rssi);
        });
        
        setState(() {
          _scanResults = filteredResults;
          print("DEBUG: Showing ${_scanResults.length} devices");
          if (_scanResults.isEmpty && _isScanning) {
            final obdCount = filteredResults.where((r) => 
              _isObdDevice(r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName)).length;
            _statusMessage = "Scanning for devices... Found ${results.length} total devices${obdCount > 0 ? " ($obdCount OBD devices)" : ""}.";
                      } else if (_scanResults.isNotEmpty) {
              final obdCount = filteredResults.where((r) => 
                _isObdDevice(r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName)).length;
              _statusMessage = "Found ${_scanResults.length} device(s)${obdCount > 0 ? " ($obdCount OBD devices shown first)" : ""}. Select one to connect:";
          }
        });
      }
    }, onError: (e) {
      print("Scan Error from SettingsScreen: $e");
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = "Error scanning: $e";
        });
      }
    });
    
    try {
      widget.bleTransport.startScan(); 
    } catch (e, s) {
      print("CRITICAL ERROR starting scan: $e");
      print("Stack trace: $s");
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = "Critical error starting scan: $e";
        });
      }
      return; 
    }

    Future.delayed(const Duration(seconds: 15), () {
      if (_isScanning && mounted) {
        _stopScan();
      }
    });
  }

  void _stopScan() {
    widget.bleTransport.stopScan();
    if (mounted) {
      setState(() {
        _isScanning = false;
        if (_scanResults.isEmpty) {
          _statusMessage = "Scan stopped. No devices found.";
        } else {
          _statusMessage = "Scan stopped. Select a device.";
        }
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (!mounted) return;
    _stopScan();

    setState(() {
      _statusMessage = "Connecting to ${device.platformName.isNotEmpty ? device.platformName : device.remoteId.toString()}...";
    });

    bool success = await widget.bleTransport.connect(device);

    if (mounted) {
      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _statusMessage = "Failed to connect to ${device.platformName.isNotEmpty ? device.platformName : device.remoteId.toString()}.";
        });
      }
    }
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
        return true;
      }
    }
    
    return false;
  }

  @override
  void dispose() {
    _stopScan();
    _scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Connection'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: Icon(_isScanning ? Icons.bluetooth_searching : Icons.bluetooth),
              label: Text(_isScanning ? 'Stop Scan' : 'Scan for Devices'),
              onPressed: _isScanning ? _stopScan : _startScan,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(_statusMessage, textAlign: TextAlign.center),
          ),
          if (!_permissionsGranted && !_isScanning)
             Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                    "Bluetooth and Location permissions are required to scan for devices. Please grant them or enable in settings.",
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                ),
            ),
          if (_isScanning && _scanResults.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            )),
          Expanded(
            child: ListView.builder(
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                final result = _scanResults[index];
                final deviceName = result.device.platformName.isNotEmpty
                    ? result.device.platformName
                    : (result.advertisementData.advName.isNotEmpty
                        ? result.advertisementData.advName
                        : "Unknown Device");
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
                  subtitle: Text(result.device.remoteId.toString()),
                  trailing: Text("${result.rssi} dBm"),
                  onTap: () => _connectToDevice(result.device),
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Theme'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () { print("Theme tapped"); },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () { print("Language tapped"); },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('App Version'),
            subtitle: const Text('1.0.0'),
            onTap: () { print("App version tapped"); },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
} 