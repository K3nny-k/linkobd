import 'package:flutter/material.dart';
import 'dart:ui';
import 'l10n/app_localizations.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/app_settings_screen.dart';
import 'presentation/screens/connect_screen.dart';
import 'presentation/screens/hex_console_screen.dart';
import 'presentation/screens/sfd_screen.dart';
import 'ble_transport.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Global error handler for Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🔥 FlutterError: ${details.exceptionAsString()}');
    debugPrint('🔥 Stack trace:\n${details.stack}');
  };
  
  // Global error handler for async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🔥 PlatformError: $error');
    debugPrint('🔥 Stack trace:\n$stack');
    return true; // Prevent app from crashing
  };
  
  // It's good practice to ensure FlutterBluePlus is initialized if you use its features before runApp
  // For example, checking adapter state, though BleTransport might handle this internally if needed.
  // FlutterBluePlus.setLogLevel(LogLevel.verbose, color:true); // Optional: for debugging
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OBD-II Scanner',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      routes: {
        '/app_settings': (context) => const AppSettingsScreen(),
        '/connect': (context) {
          // Extract BleTransport from arguments
          final bleTransport = ModalRoute.of(context)!.settings.arguments as BleTransport;
          return ConnectScreen(bleTransport: bleTransport);
        },
        '/hex_console': (context) {
          // Extract BleTransport from arguments
          final bleTransport = ModalRoute.of(context)!.settings.arguments as BleTransport;
          return HexConsoleScreen(bleTransport: bleTransport);
        },
        '/sfd': (context) {
          // Extract BleTransport from arguments
          final bleTransport = ModalRoute.of(context)!.settings.arguments as BleTransport;
          return SfdScreen(bleTransport: bleTransport);
        },
      },
    );
  }
}
