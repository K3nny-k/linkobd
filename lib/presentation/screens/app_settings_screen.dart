import 'package:flutter/material.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            onTap: () => _showComingSoon(context, 'Language'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Software Version'),
            onTap: () => _showComingSoon(context, 'Software Version'),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            onTap: () => _showComingSoon(context, 'Theme'),
          ),
        ],
      ),
    );
  }
} 