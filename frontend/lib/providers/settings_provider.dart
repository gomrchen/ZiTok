import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  final SharedPreferences prefs;
  static const _kPush = 'settings_push';
  static const _kEmail = 'settings_email';
  static const _kMsgPush = 'settings_msg_push';
  static const _kLanguage = 'settings_language';
  static const _kPlayerMore = 'settings_player_more_button';
  static const _kAutoNextCountdown = 'settings_auto_next_countdown';

  static const langZh = '简体中文';
  static const langEn = 'English';

  bool pushNotifications;
  bool emailNotifications;
  bool messagePush;
  /// 播放页右上角「更多」收纳图标，默认开启
  bool playerMoreButton;
  /// 片尾「N 秒后播下一集」倒计时，默认关闭（直接切集）
  bool autoNextCountdown;
  String language;

  SettingsProvider({required this.prefs})
      : pushNotifications = prefs.getBool(_kPush) ?? true,
        emailNotifications = prefs.getBool(_kEmail) ?? false,
        messagePush = prefs.getBool(_kMsgPush) ?? true,
        playerMoreButton = prefs.getBool(_kPlayerMore) ?? true,
        autoNextCountdown = prefs.getBool(_kAutoNextCountdown) ?? false,
        language = _normalizeLanguage(prefs.getString(_kLanguage));

  static String _normalizeLanguage(String? raw) {
    if (raw == langEn || raw == 'en' || raw == 'en_US') return langEn;
    return langZh;
  }

  /// MaterialApp / gen-l10n 使用的 Locale
  Locale get locale =>
      language == langEn ? const Locale('en') : const Locale('zh');

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

  Future<void> togglePlayerMoreButton(bool v) async {
    playerMoreButton = v;
    await prefs.setBool(_kPlayerMore, v);
    notifyListeners();
  }

  Future<void> toggleAutoNextCountdown(bool v) async {
    autoNextCountdown = v;
    await prefs.setBool(_kAutoNextCountdown, v);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    language = _normalizeLanguage(lang);
    await prefs.setString(_kLanguage, language);
    notifyListeners();
  }
}
