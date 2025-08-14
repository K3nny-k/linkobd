import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import '../../ble_transport.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class HexConsoleScreen extends StatefulWidget {
  final BleTransport bleTransport;

  const HexConsoleScreen({super.key, required this.bleTransport});

  @override
  State<HexConsoleScreen> createState() => _HexConsoleScreenState();
}

class _HexConsoleScreenState extends State<HexConsoleScreen> {
  final TextEditingController _sourceAddressCtrl = TextEditingController();
  final TextEditingController _targetAddressCtrl = TextEditingController();
  final TextEditingController _dataBytesCtrl = TextEditingController();
  final TextEditingController _responseCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Uint8List>? _rawDataSubscription;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  bool _isConnected = false;
  bool _isSending = false;
  bool _waitingForConfigResponse = false;

  @override
  void initState() {
    super.initState();
    _isConnected = widget.bleTransport.isConnected;
    _setupConnectionListener();
    _setupRawDataListener();
    
    // Set default values
    _sourceAddressCtrl.text = '0x';
    _targetAddressCtrl.text = '0x';
  }

  void _setupConnectionListener() {
    _connSub = widget.bleTransport.connectionStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isConnected = (state == BluetoothConnectionState.connected);
      });
      debugPrint('🔍 UDS DIAG _isConnected=$_isConnected');
    });
  }

  void _setupRawDataListener() {
    _rawDataSubscription = widget.bleTransport.rawBytesStream.listen(
      (bytes) {
        if (mounted) {
          // Check if this is the expected config response: 55 A9 00 01 FF 00
          if (_waitingForConfigResponse && _isConfigResponse(bytes)) {
            setState(() {
              _waitingForConfigResponse = false;
            });
            debugPrint('✅ Received expected config response');
          }
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                // Parse response according to the format described
                final parsedResponse = _parseResponse(bytes);
                // Only show Rx responses, not Raw data
                if (parsedResponse.startsWith('Rx:')) {
                  _responseCtrl.text += '$parsedResponse\n';
                }
              });
              
              // Auto-scroll to bottom
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                );
              }
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _waitingForConfigResponse = false;
          });
          _showSnack('BLE Error: $error');
        }
      },
    );
  }

  bool _isConfigResponse(List<int> bytes) {
    // Check for expected config response: 55 A9 00 01 FF 00
    return bytes.length == 6 &&
           bytes[0] == 0x55 &&
           bytes[1] == 0xA9 &&
           bytes[2] == 0x00 &&
           bytes[3] == 0x01 &&
           bytes[4] == 0xFF &&
           bytes[5] == 0x00;
  }

  String _parseResponse(List<int> bytes) {
    // Parse response according to: 去掉响头:55 A9 00 xx 前面四个字节不要，最后一个字节也不要
    // For example: 55 A9 00 02 50 03 00 -> show Rx:50 03
    
    if (bytes.length < 5) {
      // If too short, show raw data
      return 'Raw: ${bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ')}';
    }
    
    // Check if it starts with 55 A9 00
    if (bytes.length >= 4 && bytes[0] == 0x55 && bytes[1] == 0xA9 && bytes[2] == 0x00) {
      // Remove first 4 bytes (55 A9 00 xx) and last byte
      final dataBytes = bytes.sublist(4, bytes.length - 1);
      final hexString = dataBytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      return 'Rx:$hexString';
    } else {
      // Show raw data if format doesn't match
      final hexString = bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      return 'Raw: $hexString';
    }
  }

  Future<void> _sendData() async {
    if (_isSending) return;
    final l10n = AppLocalizations.of(context);
    
    final sourceAddr = _sourceAddressCtrl.text.trim();
    final targetAddr = _targetAddressCtrl.text.trim();
    final dataBytes = _dataBytesCtrl.text.trim();
    
    if (sourceAddr.isEmpty || targetAddr.isEmpty || dataBytes.isEmpty) {
      _showSnack(l10n.pleaseFillInAllFields);
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // Step 1: Send configuration frame
      final configFrame = _buildConfigFrame(sourceAddr, targetAddr);
      if (configFrame == null) {
        _showSnack(l10n.invalidAddressFormat);
        return;
      }
      
      await widget.bleTransport.sendRawBytes(configFrame);
      
      // Wait for expected config response: 55 A9 00 01 FF 00
      setState(() {
        _waitingForConfigResponse = true;
      });
      
      // Wait for config response with timeout
      int waitCount = 0;
      while (_waitingForConfigResponse && waitCount < 50) { // 5 second timeout
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
      
             if (_waitingForConfigResponse) {
         setState(() {
           _waitingForConfigResponse = false;
         });
         _showSnack(l10n.configResponseTimeout);
       }
      
      // Step 2: Send data frame(s)
      final dataFrames = _buildDataFrames(dataBytes);
      if (dataFrames == null) {
        _showSnack(l10n.invalidDataBytesFormat);
        return;
      }
      
             for (final frame in dataFrames) {
         await widget.bleTransport.sendRawBytes(frame);
         await Future.delayed(const Duration(milliseconds: 50)); // Small delay between frames
       }
      
    } catch (e) {
      _showSnack('Send failed: $e');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Uint8List? _buildConfigFrame(String sourceAddr, String targetAddr) {
    try {
      // Remove '0x' prefix if present and validate hex
      final cleanSource = sourceAddr.replaceAll('0x', '').replaceAll(' ', '');
      final cleanTarget = targetAddr.replaceAll('0x', '').replaceAll(' ', '');
      
      // Validate hex strings
      if (!RegExp(r'^[0-9a-fA-F]*$').hasMatch(cleanSource) ||
          !RegExp(r'^[0-9a-fA-F]*$').hasMatch(cleanTarget)) {
        return null;
      }
      
      // Parse addresses as 32-bit values but use only lower 16 bits for the frame
      final sourceValue = int.parse(cleanSource.isEmpty ? '0' : cleanSource, radix: 16);
      final targetValue = int.parse(cleanTarget.isEmpty ? '0' : cleanTarget, radix: 16);
      
      // Build configuration frame: AA A6 FF 00 10 10 01 F4 source_address(4bytes) target_address(4bytes) 00 00 07 FF FF
      final frame = <int>[
        0xAA, 0xA6, 0xFF, 0x00, 0x10, 0x10, 0x01, 0xF4,
        // Source address (4 bytes) - pad to 4 bytes with leading zeros
        0x00, 0x00, (sourceValue >> 8) & 0xFF, sourceValue & 0xFF,
        // Target address (4 bytes) - pad to 4 bytes with leading zeros  
        0x00, 0x00, (targetValue >> 8) & 0xFF, targetValue & 0xFF,
        0x00, 0x00, 0x07, 0xFF, 0xFF
      ];
      
      return Uint8List.fromList(frame);
    } catch (e) {
      return null;
    }
  }

  List<Uint8List>? _buildDataFrames(String dataBytes) {
    try {
      // Remove '0x' prefix and spaces, validate hex
      final cleanData = dataBytes.replaceAll('0x', '').replaceAll(' ', '');
      
      if (!RegExp(r'^[0-9a-fA-F]*$').hasMatch(cleanData)) {
        return null;
      }
      
      if (cleanData.length.isOdd) return null;
      
      // Parse hex string to bytes
      final dataBytesList = <int>[];
      for (int i = 0; i < cleanData.length; i += 2) {
        dataBytesList.add(int.parse(cleanData.substring(i, i + 2), radix: 16));
      }
      
      final frames = <Uint8List>[];
      
      if (dataBytesList.length <= 7) {
        // A: Data length <= 7 bytes
        // Frame format: AA A6 00 LEN(2byte) databytes_HEX + 00
        final frame = <int>[
          0xAA, 0xA6, 0x00,
          0x00, dataBytesList.length, // LEN (2 bytes)
          ...dataBytesList,
          0x00
        ];
        frames.add(Uint8List.fromList(frame));
      } else {
        // B: Data length > 7 bytes
        // Split into multiple frames: AA A6 01(multi-frame counter) + len(2byte) + databytes_HEX + 00
        // For now, we'll send all data in one frame with counter 01
        final frame = <int>[
          0xAA, 0xA6, 0x01, // Multi-frame counter (starting at 01)
          0x00, dataBytesList.length, // LEN (2 bytes)
          ...dataBytesList,
          0x00
        ];
        frames.add(Uint8List.fromList(frame));
      }
      
      return frames;
    } catch (e) {
      return null;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _clearResponse() {
    setState(() {
      _responseCtrl.clear();
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _rawDataSubscription?.cancel();
    _sourceAddressCtrl.dispose();
    _targetAddressCtrl.dispose();
    _dataBytesCtrl.dispose();
    _responseCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.udsDiag),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearResponse,
            tooltip: l10n.clearResponse,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Source and Target Address Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.sourceAddress}: 0x',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _sourceAddressCtrl,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: l10n.enterSourceAddress,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.targetAddress}: 0x',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _targetAddressCtrl,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: l10n.enterTargetAddress,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // DataBytes HEX
            Text(
              '${l10n.dataBytes}:',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dataBytesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: l10n.enterHexDataBytes,
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            
            const SizedBox(height: 16),
            
            // Response Data
            Text(
              l10n.responseDataHex,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TextField(
                  controller: _responseCtrl,
                  maxLines: null,
                  expands: true,
                  readOnly: true,
                  scrollController: _scrollController,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                    hintText: l10n.responseDataWillAppearHere,
                  ),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Send Button
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendData,
                icon: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_isSending ? l10n.sending : l10n.send),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ),
            
            // Connection Status
            if (!_isConnected) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      l10n.notConnectedToOBDDevice,
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
} 