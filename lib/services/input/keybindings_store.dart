import 'package:shared_preferences/shared_preferences.dart';

/// 键位绑定持久化接口
abstract class KeyBindingsStore {
  /// 读取绑定配置（JSON 字符串或 null）。
  Future<String?> read();

  /// 写入绑定配置（JSON 字符串）。
  Future<void> write(String value);
}

/// SharedPreferences 实现
///
/// [key] 默认使用 `key_bindings`，可在测试时替换。
class SharedPreferencesKeyBindingsStore implements KeyBindingsStore {
  SharedPreferencesKeyBindingsStore({
    Future<SharedPreferences>? instance,
    String key = 'key_bindings',
  })  : _instance = instance ?? SharedPreferences.getInstance(),
        _key = key;

  final Future<SharedPreferences> _instance;
  final String _key;

  @override
  Future<String?> read() async {
    final prefs = await _instance;
    return prefs.getString(_key);
  }

  @override
  Future<void> write(String value) async {
    final prefs = await _instance;
    await prefs.setString(_key, value);
  }
}
