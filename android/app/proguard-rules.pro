# Flutter-specific ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Bluetooth-related classes
-keep class android.bluetooth.** { *; }
-keep class com.** { *; }

# Don't obfuscate anything
-dontobfuscate 