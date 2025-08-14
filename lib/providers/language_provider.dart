import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  Locale _locale = const Locale('en'); // Default to English
  
  // Supported languages list - can be easily extended
  static const List<Locale> supportedLanguages = [
    Locale('en'), // English
    Locale('zh'), // Chinese
    // Add more languages here in the future:
    // Locale('de'), // German
    // Locale('fr'), // French
    // Locale('es'), // Spanish
    // Locale('ja'), // Japanese
  ];
  
  Locale get locale => _locale;
  List<Locale> get availableLanguages => supportedLanguages;
  
  LanguageProvider() {
    _loadLanguage();
  }
  
  void _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    _locale = Locale(languageCode);
    notifyListeners();
  }
  
  void setLanguage(Locale locale) async {
    if (_locale == locale) return;
    
    _locale = locale;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
  }
  
  String getLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'zh':
        return '中文';
      // Add more language names here:
      // case 'de':
      //   return 'Deutsch';
      // case 'fr':
      //   return 'Français';
      // case 'es':
      //   return 'Español';
      // case 'ja':
      //   return '日本語';
      default:
        return locale.languageCode.toUpperCase();
    }
  }
} 