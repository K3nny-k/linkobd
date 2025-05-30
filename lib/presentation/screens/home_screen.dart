import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../ble_transport.dart';
import '../../obd_service.dart';
import '../../data/bridge/bridge_service.dart';
import '../widgets/function_card.dart';
import '../widgets/connect_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BleTransport _bleTransport = BleTransport();
  final BridgeService _bridgeService = BridgeService();
  ObdService? _obdService;
  
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<ObdFrame>? _obdFrameSubscription;

  bool _isConnected = false;
  BluetoothDevice? _connectedDevice;

  @override
  void initState() {
    super.initState();
    _setupConnectionListener();
  }

  void _setupConnectionListener() {
    _connectionStateSubscription = _bleTransport.connectionStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isConnected = (state == BluetoothConnectionState.connected);
        if (_isConnected) {
          _connectedDevice = _bleTransport.getConnectedDevice();
          _obdService = ObdService(
            sendCommand: _bleTransport.sendCommand,
            rawResponseStream: _bleTransport.rawResponseStream,
          );
          _listenToObdFrames();
        } else {
          _obdService?.dispose();
          _obdService = null;
          _obdFrameSubscription?.cancel();
          _connectedDevice = null;
        }
      });
    });
  }

  void _listenToObdFrames() {
    if (!mounted || _obdService == null) return;
    _obdFrameSubscription?.cancel();
    _obdFrameSubscription = _obdService!.obdFrameStream.listen(
      (frame) {
        // Handle OBD frames if needed
      },
      onError: (error) {
        // Handle errors if needed
      },
    );
  }

  void _navigateToConnect() async {
    print("🏠 Navigating to connect screen");
    final result = await Navigator.pushNamed(
      context,
      '/connect',
      arguments: _bleTransport,
    );
    
    print("🏠 Connect screen returned with result: $result");
    
    // If connection was successful, ensure state is updated
    if (result == true && mounted) {
      print("🏠 Connection successful, refreshing state");
      // Force immediate state check
      _refreshConnectionState();
      
      // Also set a small delay as backup in case stream is slow
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          print("🏠 Delayed state refresh");
          _refreshConnectionState();
        }
      });
    } else {
      print("🏠 Connection was not successful or widget not mounted");
    }
  }

  void _refreshConnectionState() {
    final currentDevice = _bleTransport.getConnectedDevice();
    final isCurrentlyConnected = currentDevice != null && _bleTransport.isConnected;
    
    print("🏠 Refreshing connection state: device=$currentDevice, connected=$isCurrentlyConnected");
    
    if (isCurrentlyConnected != _isConnected || currentDevice != _connectedDevice) {
      print("🏠 State changed, updating UI");
      setState(() {
        _isConnected = isCurrentlyConnected;
        _connectedDevice = currentDevice;
      });
    } else {
      print("🏠 No state change needed");
    }
  }

  Future<void> _disconnect() async {
    if (!_isConnected || _connectedDevice == null) return;

    final deviceName = _connectedDevice?.platformName ?? 
                      _connectedDevice?.remoteId.toString() ?? 
                      'device';

    // Show confirmation dialog
    final bool? shouldDisconnect = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Disconnect?'),
          content: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                const TextSpan(text: 'Are you sure you want to disconnect from '),
                TextSpan(
                  text: deviceName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '?'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Disconnect'),
            ),
          ],
        );
      },
    );

    // If user confirmed, proceed with disconnect
    if (shouldDisconnect == true && mounted) {
      try {
        await _bleTransport.disconnect();
        
        // Force immediate state update after disconnect
        if (mounted) {
          _refreshConnectionState();
          
          // Also set a small delay as backup in case stream is slow
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              _refreshConnectionState();
            }
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Disconnected')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to disconnect')),
          );
        }
      }
    }
  }

  void _onFunctionTap(String function) {
    // Settings should be accessible without connection
    if (function == 'Settings') {
      Navigator.pushNamed(context, '/app_settings');
      return;
    }
    
    // Hex Console should be accessible without connection (it will show a warning)
    if (function == 'Hex Console') {
      Navigator.pushNamed(context, '/hex_console', arguments: _bleTransport);
      return;
    }
    
    // Other functions require connection
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect to a device first')),
      );
      return;
    }
    
    // Handle function navigation based on function name
    switch (function) {
      case 'Others':
        // TODO: Navigate to Others screen
        _showComingSoon('Others');
        break;
      case 'Diagnosis':
        // TODO: Navigate to Diagnosis screen
        _showComingSoon('Diagnosis');
        break;
      case 'SFD':
        Navigator.pushNamed(context, '/sfd', arguments: _bleTransport);
        break;
      case 'Maintenance Reset':
        // TODO: Navigate to Maintenance Reset screen
        _showComingSoon('Maintenance Reset');
        break;
      case 'Read/Write Config':
        // TODO: Navigate to Read/Write Config screen
        _showComingSoon('Read/Write Config');
        break;
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature feature coming soon')),
    );
  }

  /// Connect bridge between BLE and TCP
  Future<bool> connectBridge(String tcpHost, int tcpPort) async {
    if (!_isConnected) {
      print('Bridge: BLE not connected');
      return false;
    }

    try {
      final success = await _bridgeService.startBleToTcp(_bleTransport, tcpHost, tcpPort);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bridge connected to $tcpHost:$tcpPort')),
        );
      }
      return success;
    } catch (e) {
      print('Bridge: Connection failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bridge connection failed: $e')),
        );
      }
      return false;
    }
  }

  /// Disconnect bridge
  void disconnectBridge() {
    if (_bridgeService.isActive) {
      _bridgeService.stopBridge();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bridge disconnected')),
        );
      }
    }
  }

  @override
  void dispose() {
    _connectionStateSubscription?.cancel();
    _obdFrameSubscription?.cancel();
    _bridgeService.dispose();
    _bleTransport.dispose();
    _obdService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('OBD-II Scanner'),
        backgroundColor: theme.colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Connection status indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isConnected 
                ? theme.colorScheme.primaryContainer 
                : theme.colorScheme.errorContainer,
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: _isConnected 
                      ? theme.colorScheme.onPrimaryContainer 
                      : theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected 
                      ? 'Connected to ${_connectedDevice?.platformName ?? _connectedDevice?.remoteId.toString() ?? 'device'}'
                      : 'Not connected',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _isConnected 
                        ? theme.colorScheme.onPrimaryContainer 
                        : theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
          
          // Function grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  FunctionCard(
                    title: 'Settings',
                    icon: Icons.settings,
                    onTap: () => _onFunctionTap('Settings'),
                  ),
                  FunctionCard(
                    title: 'Others',
                    icon: Icons.more_horiz,
                    onTap: () => _onFunctionTap('Others'),
                  ),
                  FunctionCard(
                    title: 'Diagnosis',
                    icon: Icons.medical_services,
                    onTap: () => _onFunctionTap('Diagnosis'),
                  ),
                  FunctionCard(
                    title: 'SFD',
                    icon: Icons.storage,
                    onTap: () => _onFunctionTap('SFD'),
                  ),
                  FunctionCard(
                    title: 'Maintenance Reset',
                    icon: Icons.build,
                    onTap: () => _onFunctionTap('Maintenance Reset'),
                  ),
                  FunctionCard(
                    title: 'Read/Write Config',
                    icon: Icons.edit_document,
                    onTap: () => _onFunctionTap('Read/Write Config'),
                  ),
                  FunctionCard(
                    title: 'Hex Console',
                    icon: Icons.code,
                    onTap: () => _onFunctionTap('Hex Console'),
                  ),
                  FunctionCard(
                    title: 'Placeholder B',
                    icon: Icons.help_outline,
                    isEnabled: false,
                  ),
                ],
              ),
            ),
          ),
          
          // Connect/Disconnect button
          ConnectButton(
            isConnected: _isConnected,
            deviceName: _connectedDevice?.platformName ?? _connectedDevice?.remoteId.toString(),
            onConnect: _navigateToConnect,
            onDisconnect: _disconnect,
          ),
        ],
      ),
    );
  }
} 