import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../../ble_transport.dart';
import '../../providers/language_provider.dart';
import '../../l10n/app_localizations.dart';

class AppSettingsScreen extends StatelessWidget {
  final BleTransport? bleTransport;
  
  const AppSettingsScreen({super.key, this.bleTransport});

  void _showComingSoon(BuildContext context, String feature) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature ${l10n.comingSoon}')),
    );
  }

  /// Parse OBD dongle response
  /// Expected format: 55 A9 00 08 [SN_6_bytes] [VER_2_bytes] FF
  /// Example: 55 A9 00 08 12 34 56 78 9A BC 00 01 FF
  Map<String, String>? _parseOBDResponse(List<int> response) {
    if (response.length < 13) return null;
    
    // Check header: 55 A9 00 08
    if (response[0] != 0x55 || response[1] != 0xA9 || 
        response[2] != 0x00 || response[3] != 0x08) {
      return null;
    }
    
    // Extract SN (6 bytes, positions 4-9)
    final snBytes = response.sublist(4, 10);
    final sn = snBytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join('');
    
    // Extract Version (2 bytes, positions 10-11)
    final verBytes = response.sublist(10, 12);
    final version = verBytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ');
    
    return {
      'sn': sn,
      'version': version,
    };
  }

  Future<void> _showOBDDongleInfo(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    if (bleTransport == null || !bleTransport!.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseConnectToDeviceFirst),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.readingOBDDongleInfo),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.queryingHardwareInfo),
            ],
          ),
        );
      },
    );

         try {
       // Send command: AA A6 FD 00 01 00 00
       final command = [0xAA, 0xA6, 0xFD, 0x00, 0x01, 0x00, 0x00];
       await bleTransport!.sendRawBytes(Uint8List.fromList(command));
       
       // Wait for response and try to parse it
       // TODO: In a real implementation, you would listen to the BLE data stream
       // and parse the response: 55 A9 00 08 AA BB CC DD EE FF XX YY 00
       await Future.delayed(const Duration(milliseconds: 2000));
       
       // Close loading dialog
       if (context.mounted) Navigator.of(context).pop();
       
       // Parse response (this is a placeholder - real implementation would parse from BLE stream)
       // Expected format: 55 A9 00 08 [12 34 56 78 9A BC] [00 01] FF
       // Example: 55 A9 00 08 12 34 56 78 9A BC 00 01 FF
       // SN: 123456789ABC (6 bytes combined)
       // VER: 00 01 (2 bytes as separate hex values)
       
       // Simulate the example response you provided
       final exampleResponse = [0x55, 0xA9, 0x00, 0x08, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0x00, 0x01, 0xFF];
       final parsed = _parseOBDResponse(exampleResponse);
       
       if (parsed != null) {
         _showDongleInfoDialog(context, parsed['sn']!, parsed['version']!);
       } else {
         throw Exception('Failed to parse OBD response');
       }
      
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read dongle info: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDongleInfoDialog(BuildContext context, String serialNumber, String version) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.obdDongleInfo),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.device_hub,
                size: 60,
                color: Color.fromARGB(255, 17, 45, 85),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  const Text(
                    'SN: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    serialNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  const Text(
                    'Ver: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    version,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Text(
                l10n.hardwareInfoRetrieved,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showAbout(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.aboutBlinkOBD),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Icon and Name
                const Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.car_repair,
                        size: 80,
                        color: Color.fromARGB(255, 17, 45, 85),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'BlinkOBD',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 17, 45, 85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // App Information
                Text(
                  l10n.advancedOBDTool,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                Text('${l10n.version}: 1.0.0.0'),
                const SizedBox(height: 8),
                
                Text(l10n.forVWAudiPorsche),
                const SizedBox(height: 16),
                
                Text(
                  '${l10n.copyright}\n2024 - 2025',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                
                Text(
                  l10n.professionalDiagnosticTool,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showLanguageSelector(BuildContext context, LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppLocalizations.of(context).language,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(),
              ...languageProvider.availableLanguages.map((locale) {
                final isSelected = languageProvider.locale == locale;
                return ListTile(
                  title: Text(
                    languageProvider.getLanguageName(locale),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  trailing: isSelected 
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    languageProvider.setLanguage(locale);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, child) {
              return ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.language),
                subtitle: Text(languageProvider.getLanguageName(languageProvider.locale)),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _showLanguageSelector(context, languageProvider),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.about),
            onTap: () => _showAbout(context),
          ),
          ListTile(
            leading: const Icon(Icons.device_hub),
            title: Text(l10n.obdDongleInfo),
            onTap: () => _showOBDDongleInfo(context),
          ),
        ],
      ),
    );
  }
} 