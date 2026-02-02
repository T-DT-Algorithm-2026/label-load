import 'package:shared_preferences/shared_preferences.dart';

/// 轻量持久化设置存储接口
///
/// 统一读写应用级别的标量配置，便于替换不同的存储实现。
abstract class SettingsStore {
  /// 读取整数配置，未设置返回 null。
  Future<int?> getInt(String key);

  /// 读取浮点配置，未设置返回 null。
  Future<double?> getDouble(String key);

  /// 读取布尔配置，未设置返回 null。
  Future<bool?> getBool(String key);

  /// 写入整数配置。
  Future<void> setInt(String key, int value);

  /// 写入浮点配置。
  Future<void> setDouble(String key, double value);

  /// 写入布尔配置。
  Future<void> setBool(String key, bool value);
}

/// SharedPreferences 实现
///
/// [instance] 允许注入 mock 以便于单元测试。
class SharedPreferencesStore implements SettingsStore {
  SharedPreferencesStore({Future<SharedPreferences>? instance})
      : _instance = instance ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _instance;

  @override
  Future<int?> getInt(String key) async {
    final prefs = await _instance;
    return prefs.getInt(key);
  }

  @override
  Future<double?> getDouble(String key) async {
    final prefs = await _instance;
    return prefs.getDouble(key);
  }

  @override
  Future<bool?> getBool(String key) async {
    final prefs = await _instance;
    return prefs.getBool(key);
  }

  @override
  Future<void> setInt(String key, int value) async {
    final prefs = await _instance;
    await prefs.setInt(key, value);
  }

  @override
  Future<void> setDouble(String key, double value) async {
    final prefs = await _instance;
    await prefs.setDouble(key, value);
  }

  @override
  Future<void> setBool(String key, bool value) async {
    final prefs = await _instance;
    await prefs.setBool(key, value);
  }
}
