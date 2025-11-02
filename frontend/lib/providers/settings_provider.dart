import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  final SharedPreferences prefs;
  static const _kPush = 'settings_push';
  static const _kEmail = 'settings_email';
  static const _kMsgPush = 'settings_msg_push';
  static const _kLanguage = 'settings_language';

  bool pushNotifications;
  bool emailNotifications;
  bool messagePush;
  String language;

  SettingsProvider({required this.prefs})
      : pushNotifications = prefs.getBool(_kPush) ?? true,
        emailNotifications = prefs.getBool(_kEmail) ?? false,
        messagePush = prefs.getBool(_kMsgPush) ?? true,
        language = prefs.getString(_kLanguage) ?? 'English';

  Future<void> togglePush(bool v) async {
    pushNotifications = v;
    await prefs.setBool(_kPush, v);
    notifyListeners();
  }

  Future<void> toggleEmail(bool v) async {
    emailNotifications = v;
    await prefs.setBool(_kEmail, v);
    notifyListeners();
  }

  Future<void> toggleMessagePush(bool v) async {
    messagePush = v;
    await prefs.setBool(_kMsgPush, v);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    language = lang;
    await prefs.setString(_kLanguage, lang);
    notifyListeners();
  }
}