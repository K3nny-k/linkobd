import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'l10n/app_localizations.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/app_settings_screen.dart';
import 'presentation/screens/connect_screen.dart';
import 'presentation/screens/hex_console_screen.dart';
import 'presentation/screens/sfd_screen.dart';
import 'presentation/screens/maintenance_reset_screen.dart';
import 'presentation/screens/diagnosis_screen.dart';
import 'presentation/screens/config_screen.dart';
import 'providers/language_provider.dart';

import 'ble_transport.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enhanced global error handler for Flutter errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('🔥🔥🔥 FLUTTER ERROR DETECTED 🔥🔥🔥');
    print('🔥 Error: ${details.exceptionAsString()}');
    print('🔥 Library: ${details.library}');
    print('🔥 Context: ${details.context}');
    print('🔥 Stack trace:\n${details.stack}');
    print('🔥🔥🔥 END FLUTTER ERROR 🔥🔥🔥');
  };
  
  // Enhanced global error handler for async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    print('💥💥💥 PLATFORM ERROR DETECTED 💥💥💥');
    print('💥 Error: $error');
    print('💥 Error Type: ${error.runtimeType}');
    print('💥 Stack trace:\n$stack');
    print('💥💥💥 END PLATFORM ERROR 💥💥💥');
    return true; // Prevent app from crashing
  };
  
  // Enable verbose Flutter Blue Plus logging
  // FlutterBluePlus.setLogLevel(LogLevel.verbose, color:true);
  
  print('🚀 Starting BlinkOBD application...');
  
  try {
  runApp(const MyApp());
    print('✅ App started successfully');
  } catch (e, stackTrace) {
    print('❌ Failed to start app: $e');
    print('❌ Stack trace: $stackTrace');
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LanguageProvider(),
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
    return MaterialApp(
            title: 'BlinkOBD',
      debugShowCheckedModeBanner: false,
            locale: languageProvider.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 17, 45, 85),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 17, 45, 85),
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 17, 45, 85),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 12, 35, 65),
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        scaffoldBackgroundColor: Color.fromARGB(255, 18, 18, 18),
        cardColor: Color.fromARGB(255, 28, 28, 30),
      ),
      themeMode: ThemeMode.system, // 自动跟随系统主题
      home: const HomeScreen(),
      routes: {
        '/app_settings': (context) {
          // Extract BleTransport from arguments (can be null)
          final bleTransport = ModalRoute.of(context)?.settings.arguments as BleTransport?;
          return AppSettingsScreen(bleTransport: bleTransport);
        },
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
        '/maintenance_reset': (context) {
          // Extract BleTransport from arguments
          final bleTransport = ModalRoute.of(context)!.settings.arguments as BleTransport;
          return MaintenanceResetScreen(bleTransport: bleTransport);
        },
        '/diagnosis': (context) {
          // Extract BleTransport from arguments
          final bleTransport = ModalRoute.of(context)!.settings.arguments as BleTransport;
          return DiagnosisScreen(bleTransport: bleTransport);
        },
        '/config': (context) {
          // Extract BleTransport from arguments
          final bleTransport = ModalRoute.of(context)!.settings.arguments as BleTransport;
          return ConfigScreen(bleTransport: bleTransport);
        },
      },
            );
          },
        ),
    );
  }
}
