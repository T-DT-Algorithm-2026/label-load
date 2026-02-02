import 'package:flutter/material.dart';
import '../services/app/app_error.dart';
import '../services/settings/theme_store.dart';
import 'app_error_state.dart';

/// 主题状态管理
///
/// 管理应用的明暗主题切换，并持久化用户偏好。
class ThemeProvider extends ChangeNotifier with AppErrorState {
  static const String _themeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;
  bool _isInitialized = false;
  final ThemeStore _store;

  /// 当前主题模式。
  ThemeMode get themeMode => _themeMode;

  /// 是否为暗色主题。
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// 是否已完成加载。
  bool get isInitialized => _isInitialized;

  ThemeProvider({ThemeStore? store})
      : _store = store ?? SharedPreferencesThemeStore(key: _themeKey) {
    _loadTheme();
  }

  /// 从本地存储加载主题设置
  Future<void> _loadTheme() async {
    try {
      final isDark = await _store.readIsDark() ?? true;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (e, stack) {
      reportError(
        e,
        AppErrorCode.unexpected,
        stackTrace: stack,
        details: 'load theme: $e',
        notify: false,
      );
      _themeMode = ThemeMode.dark;
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// 切换明暗主题
  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    await _saveTheme();
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
      await _saveTheme();
    }
  }

  /// 保存主题设置到本地存储
  Future<void> _saveTheme() async {
    try {
      await _store.writeIsDark(_themeMode == ThemeMode.dark);
    } catch (e, stack) {
      reportError(
        e,
        AppErrorCode.ioOperationFailed,
        stackTrace: stack,
        details: 'save theme: $e',
        notify: false,
      );
    }
  }
}
