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
    final l10n = AppLocalizations.of(context);
    final data = _viewModel.sfdReceivedData;
    await Clipboard.setData(ClipboardData(text: data));
    _showSnack(l10n.copied);
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

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    
    if (_viewModel.selectedEcu == null) {
      _showSnack('Please select a device first.');
      return;
    }
    
    final bytes = sanitizeHex(_inputCtrl.text);
    if (bytes == null) {
      _showSnack(l10n.invalidHex);
      return;
    }

    try {
      debugPrint('SFD send size = ${bytes.length}');
      await _viewModel.sendSfdData(bytes);
      _showSnack(l10n.sentBytes(bytes.length));
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

                  /// -------- BUTTON ROW --------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Consumer<BluetoothViewModel>(
                        builder: (context, vm, child) {
                          final ready = vm.isConnected && vm.selectedEcu != null;
                          return FilledButton(
                            onPressed: ready ? _fetch : null,
                            child: Text(l10n.fetch),
                          );
                        },
                      ),
                      Consumer<BluetoothViewModel>(
                        builder: (context, vm, child) {
                          final ready = vm.isConnected && vm.selectedEcu != null;
                          return FilledButton(
                            onPressed: ready ? _copy : null,
                            child: Text(l10n.copy),
                          );
                        },
                      ),
                      Consumer<BluetoothViewModel>(
                        builder: (context, vm, child) {
                          return FilledButton(
                            onPressed: () => vm.clearSfdBuffer(),
                            child: Text(l10n.clear),
                          );
                        },
                      ),
                    ],
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
                      return FilledButton.icon(
                        onPressed: ready ? _send : null,
                        icon: const Icon(Icons.send),
                        label: Text(l10n.send),
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