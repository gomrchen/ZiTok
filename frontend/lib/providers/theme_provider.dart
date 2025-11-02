import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../theme/theme_tokens.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeData _theme = AppTheme.light;
  String _themeName = 'light';
  final SharedPreferences prefs;
  final Map<String, ThemeData> _registry = {
    'light': AppTheme.light,
    'dark': AppTheme.dark,
  };

  ThemeProvider({required this.prefs}) {
    final saved = prefs.getString('theme_name');
    if (saved != null && _registry.containsKey(saved)) {
      _themeName = saved;
      _theme = _registry[saved]!;
    }
  }

  ThemeData get theme => _theme;
  String get themeName => _themeName;

  void registerTheme(String name, AppColors colors, {Brightness brightness = Brightness.light}) {
    _registry[name] = AppTheme.build(colors, brightness: brightness);
    notifyListeners();
  }

  Future<void> switchTheme(String name) async {
    if (_registry.containsKey(name)) {
      _themeName = name;
      _theme = _registry[name]!;
      await prefs.setString('theme_name', name);
      notifyListeners();
    }
  }

  Future<void> toggleDark() async {
    await switchTheme(_themeName == 'dark' ? 'light' : 'dark');
  }
}