import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../ble_transport.dart';
import '../../l10n/app_localizations.dart';
import '../view_models/bluetooth_view_model.dart';
import '../widgets/searchable_ecu_selector.dart';



class SfdScreen extends StatefulWidget {
  final BleTransport bleTransport;

  const SfdScreen({super.key, required this.bleTransport});

  @override
  State<SfdScreen> createState() => _SfdScreenState();
}

class _SfdScreenState extends State<SfdScreen> {
  final TextEditingController _viewCtrl = TextEditingController();
  final TextEditingController _inputCtrl = TextEditingController();
  late BluetoothViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = BluetoothViewModel(widget.bleTransport);
  }

  @override
  void dispose() {
    _viewCtrl.dispose();
    _inputCtrl.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final l10n = AppLocalizations.of(context);
    
    if (_viewModel.selectedEcu == null) {
      _showSnack('Please select a device first.');
      return;
    }
    
    try {
      await _viewModel.requestSfdInfo();
      // Data will be updated via the stream listener
    } catch (e) {
      _showSnack('${l10n.failedToFetch}: $e');
    }
  }

  Future<void> _copy() async {
    // Extract specific frame data starting from 6th byte (71 01 C0 08 24 pattern)
    final specificData = _viewModel.getSpecificFrameDataForCopy();
    
    if (specificData.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: specificData));
      _showSnack('已复制特定帧数据: ${specificData.length > 50 ? '${specificData.substring(0, 50)}...' : specificData}');
    } else {
      // Fallback to copying all data if specific frame not found
      final allData = _viewModel.sfdReceivedData;
      await Clipboard.setData(ClipboardData(text: allData));
      _showSnack('未找到特定帧，已复制所有数据');
    }
  }

  Uint8List? sanitizeHex(String text) {
    // 1. Remove labels before any colon
    text = text.replaceAllMapped(RegExp(r'.*?:'), (_) => '');
    // 2. Strip all non-hex chars
    final hex = text.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (hex.isEmpty || hex.length.isOdd) return null;
    final bytes = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }



  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }



  /// Send long data with framing (Python-style)
  Future<void> _sendLongData() async {
    if (_inputCtrl.text.trim().isEmpty) {
      _showSnack('Please enter hex data to send as long frames');
      return;
    }

    try {
      _showSnack('📦 Sending long data with framing...');
      
      final success = await _viewModel.sendLongDataWithFraming(_inputCtrl.text.trim());
      
      if (success) {
        _showSnack('🎉 Long data sent with framing and ACK received!');
      } else {
        _showSnack('❌ Long data framing failed - check console for details');
      }
    } catch (e) {
      _showSnack('❌ Long data error: $e');
    }
  }

  /// Widget to display SFD activation status
  Widget _buildSfdStatusWidget(BluetoothViewModel viewModel) {
    final status = viewModel.sfdActivationState;
    final isActive = status['isActive'] as bool;
    final minutes = status['minutes'] as int;
    
    return Container(
      width: 65,
      height: 45,
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade100 : Colors.grey.shade300,
        border: Border.all(
          color: isActive ? Colors.green : Colors.grey,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          isActive ? '${minutes.toString().padLeft(2, '0')}m' : '00',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.green.shade800 : Colors.grey.shade600,
            fontFamily: 'RobotoMono',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<BluetoothViewModel>(
        builder: (context, vm, child) {
          // Update the view controller with received data
          _viewCtrl.text = vm.sfdReceivedData;
          
          return Scaffold(
            appBar: AppBar(
              title: const Text('SFD'),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  /// -------- ECU SELECTION DROPDOWN --------
                  const SearchableEcuSelector(),
                  const SizedBox(height: 12),

                  /// -------- SFD STATUS DISPLAY --------
                  Row(
                    children: [
                      const Text(
                        'SFD Status:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Consumer<BluetoothViewModel>(
                        builder: (context, vm, child) {
                          return _buildSfdStatusWidget(vm);
                        },
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 12),

                  /// -------- UPPER VIEW AREA --------
                  Expanded(
                    flex: 1,
                    child: Scrollbar(
                      child: TextField(
                        controller: _viewCtrl,
                        readOnly: true,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(fontFamily: 'RobotoMono'),
                        decoration: InputDecoration(
                          labelText: l10n.receivedData,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  /// -------- CONTROL BUTTONS --------
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: Consumer<BluetoothViewModel>(
                              builder: (context, vm, child) {
                                final ready = vm.isConnected && vm.selectedEcu != null;
                                return FilledButton.icon(
                                  onPressed: ready ? _fetch : null,
                                  icon: const Icon(Icons.download),
                                  label: Text(l10n.fetch),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Consumer<BluetoothViewModel>(
                              builder: (context, vm, child) {
                                final ready = vm.isConnected && vm.selectedEcu != null;
                                return FilledButton.icon(
                                  onPressed: ready ? _copy : null,
                                  icon: const Icon(Icons.copy),
                                  label: Text(l10n.copy),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Consumer<BluetoothViewModel>(
                              builder: (context, vm, child) {
                                return FilledButton.icon(
                                  onPressed: () => vm.clearSfdBuffer(),
                                  icon: const Icon(Icons.clear_all),
                                  label: Text(l10n.clear),
                                  style: FilledButton.styleFrom(
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
                  const SizedBox(height: 12),

                  /// -------- LOWER INPUT AREA --------
                  Expanded(
                    flex: 1,
                    child: Scrollbar(
                      child: TextField(
                        controller: _inputCtrl,
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(fontFamily: 'RobotoMono'),
                        decoration: InputDecoration(
                          labelText: l10n.inputData,
                          hintText: l10n.pasteHexTextHere,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  /// -------- SEND BUTTON --------
                  Consumer<BluetoothViewModel>(
                    builder: (context, vm, child) {
                      final ready = vm.isConnected && vm.selectedEcu != null;
                      return SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: ready ? _sendLongData : null,
                          icon: const Icon(Icons.send),
                          label: const Text('Send'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      );
                    },
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