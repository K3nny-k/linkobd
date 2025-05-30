import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../ble_transport.dart';

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
        if (mounted) {
          setState(() {
            _scanResults = results;
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
        const SnackBar(content: Text('Connecting...')),
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
            const SnackBar(content: Text('Connection failed')),
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
          SnackBar(content: Text('Connection failed: $e')),
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

  @override
  void dispose() {
    print("📱 ConnectScreen disposing");
    _stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("📱 ConnectScreen build - scanning: $_isScanning, results: ${_scanResults.length}");
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _startScan,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isScanning && _scanResults.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning for devices...'),
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
                      const Text('No devices found'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh),
                        label: const Text('Scan Again'),
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
                    
                    return ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(deviceName),
                      subtitle: Text(result.device.remoteId.toString()),
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