import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../ble_transport.dart';
import '../../l10n/app_localizations.dart';

class ConfigScreen extends StatefulWidget {
  final BleTransport bleTransport;

  const ConfigScreen({super.key, required this.bleTransport});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  bool _isEcuResetProcessing = false;
  bool _isClearDtcProcessing = false;
  String _statusMessage = '';

  void _showMessage(String message) {
    setState(() {
      _statusMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _performEcuReset() async {
    final l10n = AppLocalizations.of(context);
    if (!widget.bleTransport.isConnected) {
      _showMessage(l10n.pleaseConnectToDeviceFirst);
      return;
    }

    if (_isEcuResetProcessing) return;

    setState(() {
      _isEcuResetProcessing = true;
      _statusMessage = l10n.performingECUReset;
    });

    try {
      // First send: AA A6 FF 00 10 10 01 F4 00 00 07 00 00 00 07 00 00 00 07 00 FF
      // Wait for: 55 A9 00 01 FF 00
      // Then send: AA A6 00 00 02 11 02 00
      
      final firstCommand = [
        0xAA, 0xA6, 0xFF, 0x00, 0x10, 0x10, 0x01, 0xF4, 0x00, 0x00, 0x07, 0x00, 
        0x00, 0x00, 0x07, 0x00, 0x00, 0x00, 0x07, 0x00, 0xFF
      ];
      
      await widget.bleTransport.sendRawBytes(Uint8List.fromList(firstCommand));
      
      // Wait for first response: 55 A9 00 01 FF 00
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Send second command: AA A6 00 00 02 11 02 00
      final secondCommand = [0xAA, 0xA6, 0x00, 0x00, 0x02, 0x11, 0x02, 0x00];
      await widget.bleTransport.sendRawBytes(Uint8List.fromList(secondCommand));
      
      await Future.delayed(const Duration(milliseconds: 1000));
      
      _showMessage(l10n.ecuResetCompleted);
      
    } catch (e) {
      _showMessage('ECU reset failed: $e');
    } finally {
      setState(() {
        _isEcuResetProcessing = false;
      });
    }
  }

  Future<void> _clearAllDtc() async {
    final l10n = AppLocalizations.of(context);
    if (!widget.bleTransport.isConnected) {
      _showMessage(l10n.pleaseConnectToDeviceFirst);
      return;
    }

    if (_isClearDtcProcessing) return;

    setState(() {
      _isClearDtcProcessing = true;
      _statusMessage = l10n.clearingAllDTCs;
    });

    try {
      // 1. Send configuration frame: AA A6 FF 00 10 10 01 F4 00 00 07 00 00 00 07 00 00 00 07 00 FF
      // Wait for response: 55 A9 00 01 FF 00
      final configCommand = [
        0xAA, 0xA6, 0xFF, 0x00, 0x10, 0x10, 0x01, 0xF4, 0x00, 0x00, 0x07, 0x00, 
        0x00, 0x00, 0x07, 0x00, 0x00, 0x00, 0x07, 0x00, 0xFF
      ];
      
      final configBytes = Uint8List.fromList(configCommand);
      final configHex = configBytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      print("🔧 Clear DTC Config: $configHex");
      
      await widget.bleTransport.sendRawBytes(configBytes);
              setState(() {
          _statusMessage = '${l10n.configurationSent}, ${l10n.waitingResponse}';
        });
      
      // Wait for configuration response: 55 A9 00 01 FF 00
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // 2. Send frame sequence with 100ms intervals (no response waiting)
      final frameCommands = [
        // Frame 1: AA A6 00 00 01 04 00
        [0xAA, 0xA6, 0x00, 0x00, 0x01, 0x04, 0x00],
        // Frame 2: AA A6 00 00 04 14 FF FF FF 00
        [0xAA, 0xA6, 0x00, 0x00, 0x04, 0x14, 0xFF, 0xFF, 0xFF, 0x00],
        // Frame 3: AA A6 00 00 01 04 00
        [0xAA, 0xA6, 0x00, 0x00, 0x01, 0x04, 0x00],
        // Frame 4: AA A6 00 00 04 14 FF FF FF 00
        [0xAA, 0xA6, 0x00, 0x00, 0x04, 0x14, 0xFF, 0xFF, 0xFF, 0x00],
      ];
      
              for (int i = 0; i < frameCommands.length; i++) {
          setState(() {
            _statusMessage = '${l10n.sendingFrame} ${i + 1}/4...';
          });
        
        final frameBytes = Uint8List.fromList(frameCommands[i]);
        final hexString = frameBytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
        
        // Debug output to confirm what we're sending
        print("🔧 Clear DTC Frame ${i + 1}/4: $hexString");
        
        await widget.bleTransport.sendRawBytes(frameBytes);
        
        // Wait 100ms before next frame (no response waiting)
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
              _showMessage(l10n.allDTCsCleared);
      
    } catch (e) {
      _showMessage('Clear DTC failed: $e');
    } finally {
      setState(() {
        _isClearDtcProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).resetClearDtc),
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
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ECU Reset Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.restart_alt,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.ecuReset,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                l10n.resetECUToDefaults,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isEcuResetProcessing ? null : _performEcuReset,
                        icon: _isEcuResetProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.restart_alt),
                        label: Text(_isEcuResetProcessing ? 'Resetting...' : 'Reset ECU'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // Clear All DTC Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.clear_all,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.clearAllDTC,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                l10n.clearAllDiagnosticCodes,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isClearDtcProcessing ? null : _clearAllDtc,
                        icon: _isClearDtcProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.clear_all),
                        label: Text(_isClearDtcProcessing ? 'Clearing...' : 'Clear DTCs'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Warning Notice
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                border: Border.all(color: Colors.amber),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: Colors.amber[700],
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.warning,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.operationWarning,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 