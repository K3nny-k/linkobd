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
  final TextEditingController _sendCtrl = TextEditingController();
  final TextEditingController _recvCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Uint8List>? _rawDataSubscription;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _isConnected = widget.bleTransport.isConnected;
    _setupConnectionListener();
    _setupRawDataListener();
  }

  void _setupConnectionListener() {
    _connSub = widget.bleTransport.connectionStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isConnected = (state == BluetoothConnectionState.connected);
      });
      debugPrint('🔍 HexConsole _isConnected=$_isConnected');
    });
  }

  void _setupRawDataListener() {
    _rawDataSubscription = widget.bleTransport.rawBytesStream.listen(
      (bytes) {
        if (mounted) {
          // Convert received bytes to hex representation
          final hexString = bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
          
          setState(() {
            _recvCtrl.text += '$hexString\n';
          });
          
          // Auto-scroll to bottom
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
              );
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _recvCtrl.text += 'Error: $error\n';
          });
        }
      },
    );
  }

  void _sendHex() async {
    final l10n = AppLocalizations.of(context);
    final txt = _sendCtrl.text.replaceAll(RegExp(r'\s+'), '');
    if (txt.isEmpty) return;
    
    if (txt.length.isOdd || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(txt)) {
      _showSnack(l10n.invalidHex);
      return;
    }
    
    final bytes = Uint8List(txt.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(txt.substring(i * 2, i * 2 + 2), radix: 16);
    }
    
    try {
      await widget.bleTransport.sendRawBytes(bytes);
      _sendCtrl.clear();
      
      // Add sent data to receive view for reference
      final hexString = bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
      setState(() {
        _recvCtrl.text += 'SENT: $hexString\n';
      });
    } catch (e) {
      _showSnack('${l10n.sendFailed}: $e');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _clearReceive() {
    setState(() {
      _recvCtrl.clear();
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _rawDataSubscription?.cancel();
    _sendCtrl.dispose();
    _recvCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hex Console'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearReceive,
            tooltip: 'Clear receive buffer',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status banner
          if (!_isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: theme.colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.warning,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).notConnected,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Send hex input
                  TextField(
                    controller: _sendCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Send (hex)',
                      hintText: 'e.g., 01 05 or 0105',
                      border: OutlineInputBorder(),
                    ),
                    enabled: _isConnected,
                    onSubmitted: _isConnected ? (_) => _sendHex() : null,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Receive area
                  Expanded(
                    child: TextField(
                      controller: _recvCtrl,
                      scrollController: _scrollController,
                      decoration: const InputDecoration(
                        labelText: 'Receive',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      style: const TextStyle(fontFamily: 'RobotoMono'),
                      maxLines: null,
                      expands: true,
                      readOnly: true,
                      textAlignVertical: TextAlignVertical.top,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Send button
                  FilledButton.icon(
                    onPressed: _isConnected ? _sendHex : null,
                    icon: const Icon(Icons.send),
                    label: Text(AppLocalizations.of(context).send),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 