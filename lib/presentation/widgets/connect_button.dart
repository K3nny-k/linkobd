import 'package:flutter/material.dart';

class ConnectButton extends StatelessWidget {
  final bool isConnected;
  final String? deviceName;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const ConnectButton({
    super.key,
    required this.isConnected,
    this.deviceName,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: isConnected
          ? Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: null, // Disabled when connected
                    icon: const Icon(Icons.bluetooth_connected),
                    label: Text(
                      deviceName ?? 'Connected',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: onDisconnect,
                  icon: const Icon(Icons.close),
                  tooltip: 'Disconnect',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                ),
              ],
            )
          : FilledButton.icon(
              onPressed: onConnect,
              icon: const Icon(Icons.bluetooth),
              label: const Text('Connect'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
    );
  }
} 