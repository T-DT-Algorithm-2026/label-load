import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/services/settings/theme_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SharedPreferencesThemeStore reads and writes theme flag', () async {
    final store = SharedPreferencesThemeStore();

    expect(await store.readIsDark(), isNull);

    await store.writeIsDark(true);
    expect(await store.readIsDark(), true);

    await store.writeIsDark(false);
    expect(await store.readIsDark(), false);
  });

  test('SharedPreferencesThemeStore honors custom key', () async {
    final store = SharedPreferencesThemeStore(key: 'custom_theme_key');

    await store.writeIsDark(true);
    expect(await store.readIsDark(), true);

    final defaultStore = SharedPreferencesThemeStore();
    expect(await defaultStore.readIsDark(), isNull);
  });
}
