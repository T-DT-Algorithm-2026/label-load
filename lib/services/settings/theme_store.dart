import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式存储接口
abstract class ThemeStore {
  /// 读取是否为深色主题，未设置返回 null。
  Future<bool?> readIsDark();

  /// 写入是否为深色主题。
  Future<void> writeIsDark(bool value);
}

/// SharedPreferences 实现
///
/// [key] 默认使用 `theme_mode`，可在测试时替换。
class SharedPreferencesThemeStore implements ThemeStore {
  SharedPreferencesThemeStore({
    Future<SharedPreferences>? instance,
    String key = 'theme_mode',
  })  : _instance = instance ?? SharedPreferences.getInstance(),
        _key = key;

  final Future<SharedPreferences> _instance;
  final String _key;

  @override
  Future<bool?> readIsDark() async {
    final prefs = await _instance;
    return prefs.getBool(_key);
  }

  @override
  Future<void> writeIsDark(bool value) async {
    final prefs = await _instance;
    await prefs.setBool(_key, value);
  }
}
