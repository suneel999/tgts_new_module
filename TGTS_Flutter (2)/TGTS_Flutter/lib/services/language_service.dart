import 'package:flutter/material.dart';
import '../models/index.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  LanguageService() {
    _load();
  }

  static const _prefsKey = 'selected_language';
  Language _language = Language.en;

  Language get language => _language;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null) {
      _language = Language.values.firstWhere((e) => e.name == code, orElse: () => Language.en);
      notifyListeners();
    }
  }

  Future<void> setLanguage(Language lang) async {
    if (lang == _language) return;
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, lang.name);
  }

  Future<void> toggle() async {
    await setLanguage(_language == Language.en ? Language.te : Language.en);
  }
}
