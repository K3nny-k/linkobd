import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ble_transport.dart';
import '../view_models/bluetooth_view_model.dart';
import '../widgets/searchable_ecu_selector.dart';
import '../../l10n/app_localizations.dart';

class DiagnosisScreen extends StatefulWidget {
  final BleTransport bleTransport;

  const DiagnosisScreen({super.key, required this.bleTransport});

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  late BluetoothViewModel _viewModel;
  
  // Status states
  bool _isDiagnosing = false;
  String _receivedMessages = '';
  late String _initialBufferData;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _viewModel = BluetoothViewModel(widget.bleTransport);
    _initialBufferData = '';
    
    // Listen to view model changes for real-time updates
    _viewModel.addListener(_onViewModelUpdate);
  }

  void _onViewModelUpdate() {
    if (_isDiagnosing && mounted) {
      // Get latest raw data for real-time display
      final currentData = _viewModel.sfdReceivedData;
      if (currentData != _initialBufferData) {
        // Show incremental updates during diagnosis
        final newData = currentData.substring(_initialBufferData.length);
        if (newData.isNotEmpty && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                // Don't overwrite the structured diagnosis results
                if (!_receivedMessages.contains('=== DIAGNOSIS STARTED ===')) {
                  _receivedMessages += '$newData\n';
                }
              });
              _scrollToBottom();
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdate);
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  // Process diagnosis results to make them cleaner
  String _processDiagnosisResults(String rawResults) {
    if (rawResults.isEmpty) return '';
    
    final l10n = AppLocalizations.of(context);
    final lines = rawResults.split('\n');
    final Map<String, String> diagnosisData = {};
    int frameIndex = 0;
    
    for (String line in lines) {
      // Skip decorative lines
      if (line.contains('===') || line.contains('Time:') || line.isEmpty) {
        continue;
      }
      
      // Process response lines that contain hex data
      if (line.contains('Response:') && line.contains('55 A9')) {
        // Extract hex data after "Response: "
        final responseIndex = line.indexOf('Response: ');
        if (responseIndex != -1) {
          final hexData = line.substring(responseIndex + 10).trim();
          final hexBytes = hexData.split(' ');
          
          // Skip first 4 bytes (frame header) if they are 55 A9
          if (hexBytes.length >= 4 && hexBytes[0] == '55' && hexBytes[1] == 'A9') {
            final payload = hexBytes.skip(4).join(' ');
            if (payload.isNotEmpty) {
              final category = _getDiagnosisCategory(frameIndex, l10n);
              
              // Special handling for DTC data
              if (category == '${l10n.dtcStatus} 04' || category == '${l10n.dtcStatus} 08') {
                final dtcText = _parseDTC(hexData);
                if (dtcText.isNotEmpty && !dtcText.contains('Error')) {
                  diagnosisData[category] = dtcText;
                }
              } else {
                // Convert hex to ASCII for other data
                // Skip first 3 bytes of payload (service identifier and PID)
                final payloadBytes = payload.split(' ');
                final dataPayload = payloadBytes.length > 3 ? payloadBytes.skip(3).join(' ') : payload;
                final asciiText = _hexToAscii(dataPayload);
                final cleanText = _cleanAsciiText(asciiText, category);
                
                if (cleanText.isNotEmpty && cleanText != 'N/A') {
                  diagnosisData[category] = cleanText;
                }
              }
              frameIndex++;
            }
          }
        }
      } else if (line.contains('Send:') || line.contains('Frame') || line.contains('Error:') || line.contains('No response')) {
        // Skip send commands and error messages
        continue;
      }
    }
    
    // Format the results in a clean way
    return _formatDiagnosisResults(diagnosisData);
  }

  // Convert hex string to ASCII
  String _hexToAscii(String hexString) {
    try {
      final hexBytes = hexString.split(' ');
      final asciiChars = <String>[];
      
      for (String hex in hexBytes) {
        if (hex.isNotEmpty) {
          final byte = int.tryParse(hex, radix: 16);
          if (byte != null) {
            // Only convert printable ASCII characters (32-126)
            if (byte >= 32 && byte <= 126) {
              asciiChars.add(String.fromCharCode(byte));
            } else {
              // For non-printable characters, show as hex
              asciiChars.add('\\x${hex.toLowerCase()}');
            }
          }
        }
      }
      
      return asciiChars.join('');
    } catch (e) {
      // If conversion fails, return original hex string
      return hexString;
    }
  }

  // Get category name for diagnosis frame
  String _getDiagnosisCategory(int frameIndex, AppLocalizations l10n) {
    switch (frameIndex) {
      case 0: return l10n.sessionStatus;
      case 1: return l10n.vin;
      case 2: return l10n.vehicleInfo;
      case 3: return l10n.serialNumber;
      case 4: return l10n.vinExtended;
      case 5: return l10n.calibrationId;
      case 6: return l10n.systemName;
      case 7: return l10n.developmentData;
      case 8: return l10n.activeDiagnosticInfo;
      case 9: return l10n.vwSystemName;
      case 10: return l10n.auditSystemName;
      case 11: return l10n.seatSystemName;
      case 12: return l10n.systemSupplier;
      case 13: return '${l10n.dtcStatus} 04';
      case 14: return '${l10n.dtcStatus} 08';
      default: return l10n.unknownCategory;
    }
  }

  // Clean ASCII text by removing non-printable characters
  String _cleanAsciiText(String asciiText, String category) {
    // Remove hex escape sequences and non-printable characters
    final cleanText = asciiText.replaceAll(RegExp(r'\\x[0-9a-fA-F]{2}'), '');
    
    // For VIN related categories, keep dashes as they might be the actual data
    if (category.contains('VIN')) {
      final trimmed = cleanText.trim();
      // If it's all dashes, show it as is (might be valid VIN placeholder)
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    } else {
      // For other categories, remove dashes and trim
      final noDashes = cleanText.replaceAll('-', '').trim();
      if (noDashes.isNotEmpty) {
        return noDashes;
      }
    }
    
    return 'N/A';
  }

  // Parse DTC codes from hex data
  String _parseDTC(String hexData) {
    try {
      // Remove frame header (55 A9 00 23 59 02 FF)
      final hexBytes = hexData.split(' ');
      if (hexBytes.length < 7) return 'Invalid DTC data';
      
      // Skip first 7 bytes (frame header only)
      final dtcData = hexBytes.skip(7).toList();
      
      final List<String> dtcCodes = [];
      int dtcIndex = 1;
      
      // Parse DTC codes in groups of 4 bytes
      for (int i = 0; i < dtcData.length - 3; i += 4) {
        if (i + 3 < dtcData.length) {
          // Get 4 bytes for one DTC code
          final codeBytes = dtcData.sublist(i, i + 4);
          
          // First 3 bytes form the DTC code (big-endian)
          final codeHex = codeBytes.take(3).join('');
          final statusHex = codeBytes[3];
          
          // Convert to decimal
          final codeDecimal = int.tryParse(codeHex, radix: 16) ?? 0;
          final statusDecimal = int.tryParse(statusHex, radix: 16) ?? 0;
          
          // Convert status to binary
          final statusBinary = statusDecimal.toRadixString(2).padLeft(8, '0');
          
          dtcCodes.add('DTC ${dtcIndex.toString().padLeft(3, '0')}: Code 0x$codeHex ($codeDecimal) Status: 0x$statusHex ($statusBinary)');
          dtcIndex++;
        }
      }
      
      return dtcCodes.join('\n');
    } catch (e) {
      return 'Error parsing DTC: $e';
    }
  }

  // Format diagnosis results in a clean way
  String _formatDiagnosisResults(Map<String, String> data) {
    if (data.isEmpty) return 'No diagnosis data available';
    
    final List<String> formattedLines = [];
    
    // Add header
    formattedLines.add('=== DIAGNOSIS RESULTS ===');
    formattedLines.add('');
    
    // Add each category with its data
    final categories = [
      'VIN',
      'Vehicle Info',
      'Serial Number', 
      'VIN Extended',
      'Calibration ID',
      'System Name',
      'Development Data',
      'Audi System Name',
      'Seat System Name',
      'System Supplier',
      'DTC Status 04',
      'DTC Status 08'
    ];
    
    for (String category in categories) {
      if (data.containsKey(category)) {
        final value = data[category]!;
        if (value != 'N/A') {
          if (category == 'DTC Status 04' || category == 'DTC Status 08') {
            // For DTC data, add extra formatting
            formattedLines.add('$category:');
            formattedLines.add(value);
            formattedLines.add('');
          } else {
            formattedLines.add('$category: $value');
          }
        }
      }
    }
    
    return formattedLines.join('\n');
  }

  // Diagnose button action
  Future<void> _startDiagnosis() async {
    if (_isDiagnosing) return;
    
          setState(() {
        _isDiagnosing = true;
        _receivedMessages = '${AppLocalizations.of(context).startingDiagnosis}\n\n';
        _initialBufferData = _viewModel.sfdReceivedData; // Record initial state
      });

    try {
      // Run the complete diagnosis sequence
      final diagnosisResults = await _viewModel.runDiagnosis();
      
      setState(() {
        _receivedMessages = _processDiagnosisResults(diagnosisResults);
      });
      
      _scrollToBottom();
      _showMessage(AppLocalizations.of(context).diagnosisCompleted);
    } catch (e) {
      setState(() {
        _receivedMessages += '\nError: $e';
      });
      _scrollToBottom();
      _showMessage('${AppLocalizations.of(context).diagnosisFailed}: $e');
    } finally {
      setState(() {
        _isDiagnosing = false;
      });
    }
  }

  // Clear button action
  void _clearMessages() {
    setState(() {
      _receivedMessages = '';
    });
    _showMessage(AppLocalizations.of(context).messagesCleared);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<BluetoothViewModel>(
        builder: (context, vm, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.diagnosis),
            ),
            body: Column(
              children: [
                // ECU Selector
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.selectECUOptional,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            l10n.diagnosisCanRun,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const SearchableEcuSelector(),
                        ],
                      ),
                    ),
                  ),
                ),

                // Messages Display Area
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                                  Text(
                            l10n.diagnosisResults,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.outline.withOpacity(0.3),
                              ),
                            ),
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              child: Text(
                                _receivedMessages.isEmpty 
                                    ? l10n.noDiagnosisResults
                                    : _receivedMessages,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Buttons
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Diagnose Button (Left)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: vm.isConnected && !_isDiagnosing 
                              ? _startDiagnosis 
                              : null,
                          icon: _isDiagnosing 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.medical_services),
                          label: Text(l10n.diagnose),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Clear Button (Right)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _receivedMessages.isNotEmpty ? _clearMessages : null,
                          icon: const Icon(Icons.clear),
                          label: Text(l10n.clear),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: theme.colorScheme.secondary,
                            foregroundColor: theme.colorScheme.onSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 