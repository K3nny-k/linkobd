import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ble_transport.dart';
import '../view_models/bluetooth_view_model.dart';

class MaintenanceResetScreen extends StatefulWidget {
  final BleTransport bleTransport;

  const MaintenanceResetScreen({super.key, required this.bleTransport});

  @override
  State<MaintenanceResetScreen> createState() => _MaintenanceResetScreenState();
}

class _MaintenanceResetScreenState extends State<MaintenanceResetScreen> {
  late BluetoothViewModel _viewModel;
  
  // Status states
  bool _isFirewallProcessing = false;
  bool _isKombiProcessing = false;
  bool _isHeadunitProcessing = false;
  bool _isQueryingTransportMode = false;
  bool _isClosingTransportMode = false;
  String _statusMessage = '';
  bool _hasShownReminder = false;

  @override
  void initState() {
    super.initState();
    _viewModel = BluetoothViewModel(widget.bleTransport);
    
    // Initialize firewall status when connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFirewallStatus();
      _showMaintenanceReminder();
    });
  }

  void _initializeFirewallStatus() {
    if (_viewModel.isConnected) {
      _viewModel.queryFirewallStatus().catchError((error) {
        debugPrint('Failed to query initial firewall status: $error');
      });
    }
  }

  void _initializeTransportModeStatus() {
    if (_viewModel.isConnected) {
      _viewModel.queryTransportModeStatus().catchError((error) {
        debugPrint('Failed to query initial transport mode status: $error');
      });
    }
  }

  void _showMaintenanceReminder() {
    if (!_hasShownReminder && mounted) {
      _hasShownReminder = true;
      
      // Show reminder dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            icon: Icon(
              Icons.warning,
              color: Colors.orange[600],
              size: 48,
            ),
            title: const Text(
              '重要提醒',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            content: const Text(
              '保养复位请先打开引擎盖',
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  '确定',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    setState(() {
      _statusMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Button 1: Close Diagnostic Firewall
  Future<void> _closeDiagnosticFirewall() async {
    if (_isFirewallProcessing) return;
    
    setState(() {
      _isFirewallProcessing = true;
      _statusMessage = 'Checking diagnostic firewall status...';
    });

    try {
      await _viewModel.closeDiagnosticFirewall();
      
      // Check final status and update message
      final firewallStatus = _viewModel.diagnosticFirewallStatus;
      final statusStr = firewallStatus['status'];
      
      switch (statusStr) {
        case 'no_action_needed':
          _showMessage('Diagnostic firewall: No action needed');
          break;
        case 'closed':
          _showMessage('Diagnostic firewall closed successfully');
          break;
        case 'open':
          _showMessage('Diagnostic firewall is still open');
          break;
        default:
          _showMessage('Diagnostic firewall status unknown');
          break;
      }
    } catch (e) {
      _showMessage('Failed to close diagnostic firewall: $e');
    } finally {
      setState(() {
        _isFirewallProcessing = false;
      });
    }
  }

  // Button 2: Kombi 17 Reset
  Future<void> _resetKombi17() async {
    if (_isKombiProcessing) return;
    
    setState(() {
      _isKombiProcessing = true;
      _statusMessage = 'Resetting Kombi 17...';
    });

    try {
      await _viewModel.resetKombi17();
      _showMessage('Kombi 17 reset completed successfully');
    } catch (e) {
      _showMessage('Failed to reset Kombi 17: $e');
    } finally {
      setState(() {
        _isKombiProcessing = false;
      });
    }
  }

  // Button 3: Headunit 5F Reset
  Future<void> _resetHeadunit5F() async {
    if (_isHeadunitProcessing) return;
    
    setState(() {
      _isHeadunitProcessing = true;
      _statusMessage = 'Resetting Headunit 5F...';
    });

    try {
      await _viewModel.resetHeadunit5F();
      _showMessage('Headunit 5F reset completed successfully');
    } catch (e) {
      _showMessage('Failed to reset Headunit 5F: $e');
    } finally {
      setState(() {
        _isHeadunitProcessing = false;
      });
    }
  }

  // Button 4: Close Transport Mode
  Future<void> _closeTransportMode() async {
    if (_isClosingTransportMode) return;
    
    setState(() {
      _isClosingTransportMode = true;
      _statusMessage = 'Closing transport mode...';
    });

    try {
      await _viewModel.closeTransportMode();
      _showMessage('Transport mode closed successfully');
    } catch (e) {
      _showMessage('Failed to close transport mode: $e');
    } finally {
      setState(() {
        _isClosingTransportMode = false;
      });
    }
  }

  // Query Transport Mode Status
  Future<void> _queryTransportModeStatus() async {
    if (_isQueryingTransportMode) return;
    
    setState(() {
      _isQueryingTransportMode = true;
      _statusMessage = 'Querying transport mode status...';
    });

    try {
      await _viewModel.queryTransportModeStatus();
      
      // Check final status and update message
      final transportStatus = _viewModel.transportModeStatus;
      final statusStr = transportStatus['status'];
      
      switch (statusStr) {
        case 'not_activated':
          _showMessage('Transport mode: Not activated');
          break;
        case 'activated':
          _showMessage('Transport mode: Activated');
          break;
        default:
          _showMessage('Transport mode status: Unknown');
          break;
      }
    } catch (e) {
      _showMessage('Failed to query transport mode status: $e');
    } finally {
      setState(() {
        _isQueryingTransportMode = false;
      });
    }
  }

  Widget _buildFirewallStatusWidget(BluetoothViewModel viewModel) {
    final firewallStatus = viewModel.diagnosticFirewallStatus;
    Color statusColor;
    String statusText;
    
    switch (firewallStatus['status']) {
      case 'closed':
        statusColor = Colors.green;
        statusText = '防火墙关闭'; // Firewall Closed
        break;
      case 'open':
        statusColor = Colors.red;
        statusText = '防火墙开启'; // Firewall Open
        break;
      case 'no_action_needed':
        statusColor = Colors.blue;
        statusText = '无需处理'; // No Action Needed
        break;
      case 'unknown':
      default:
        statusColor = Colors.grey;
        statusText = '状态未知'; // Status Unknown
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTransportModeStatusWidget(BluetoothViewModel viewModel) {
    final transportStatus = viewModel.transportModeStatus;
    Color statusColor;
    String statusText;
    
    switch (transportStatus['status']) {
      case 'not_activated':
        statusColor = Colors.green;
        statusText = '运输模式未激活'; // Transport Mode Not Activated
        break;
      case 'activated':
        statusColor = Colors.red;
        statusText = '运输模式激活'; // Transport Mode Activated
        break;
      case 'unknown':
      default:
        statusColor = Colors.blue;
        statusText = '失败，检查SFD重试'; // Failed, Check SFD Retry
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<BluetoothViewModel>(
        builder: (context, vm, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('保养复位'), // Maintenance Reset
              backgroundColor: theme.colorScheme.inversePrimary,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Message
                  if (_statusMessage.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusMessage,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Button 1: Close Diagnostic Firewall
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '关闭诊断防火墙',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Close Diag Firewall',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildFirewallStatusWidget(vm),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: Consumer<BluetoothViewModel>(
                              builder: (context, vm, child) {
                                final ready = vm.isConnected;
                                return ElevatedButton.icon(
                                  onPressed: ready && !_isFirewallProcessing ? _closeDiagnosticFirewall : null,
                                  icon: _isFirewallProcessing 
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.security),
                                  label: const Text('执行'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Button 2: Kombi 17 Reset
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '仪表模块',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Kombi 17',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: Consumer<BluetoothViewModel>(
                              builder: (context, vm, child) {
                                final ready = vm.isConnected;
                                return ElevatedButton.icon(
                                  onPressed: ready && !_isKombiProcessing ? _resetKombi17 : null,
                                  icon: _isKombiProcessing 
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.speed),
                                  label: const Text('复位'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Button 3: Headunit 5F Reset
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '音响主机',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Headunit 5F',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: Consumer<BluetoothViewModel>(
                              builder: (context, vm, child) {
                                final ready = vm.isConnected;
                                return ElevatedButton.icon(
                                  onPressed: ready && !_isHeadunitProcessing ? _resetHeadunit5F : null,
                                  icon: _isHeadunitProcessing 
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.audio_file),
                                  label: const Text('复位'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Button 4: Close Transport Mode
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '解除运输模式',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Close Trans Mode',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildTransportModeStatusWidget(vm),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Consumer<BluetoothViewModel>(
                            builder: (context, vm, child) {
                              final ready = vm.isConnected;
                              return Row(
                                children: [
                                  // Query Button (Left)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: ready && !_isQueryingTransportMode ? _queryTransportModeStatus : null,
                                      icon: _isQueryingTransportMode 
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.search),
                                      label: const Text('查询'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Close Transport Mode Button (Right)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: ready && !_isClosingTransportMode ? _closeTransportMode : null,
                                      icon: _isClosingTransportMode 
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.local_shipping),
                                      label: const Text('解除'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
} 