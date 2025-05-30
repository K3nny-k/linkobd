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
  String _statusMessage = "Tap 'Scan' to find OBD devices.";
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
      _statusMessage = "Scanning for Nordic UART devices...";
    });

    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        print("DEBUG: Found ${results.length} BLE devices");
        for (var result in results) {
          print("DEBUG DEVICE: Name='${result.device.platformName}' AdvName='${result.advertisementData.advName}' ID=${result.device.remoteId} RSSI=${result.rssi}");
          print("DEBUG SERVICES: ${result.advertisementData.serviceUuids.map((uuid) => uuid.toString()).join(', ')}");
        }
        setState(() {
          // TEMPORARILY SHOW ALL DEVICES FOR DEBUGGING (including unnamed ones)
          _scanResults = results.toList();
          print("DEBUG: After filtering, showing ${_scanResults.length} devices");
          if (_scanResults.isEmpty && _isScanning) {
            _statusMessage = "DEBUG MODE: No named devices found yet... Found ${results.length} total devices. Check console.";
          } else if (_scanResults.isNotEmpty) {
            _statusMessage = "DEBUG MODE: Select a device to connect (Found ${results.length} total):";
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
        if (_scanResults.isEmpty) _statusMessage = "Scan stopped. No devices found.";
        else _statusMessage = "Scan stopped. Select a device.";
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: Icon(_isScanning ? Icons.bluetooth_searching : Icons.bluetooth),
              label: Text(_isScanning ? 'Stop Scan' : 'Scan for OBD Devices'),
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
                return ListTile(
                  title: Text(deviceName),
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