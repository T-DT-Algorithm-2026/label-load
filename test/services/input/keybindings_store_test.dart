import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/services/input/keybindings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SharedPreferencesKeyBindingsStore reads and writes value', () async {
    final store = SharedPreferencesKeyBindingsStore();

    expect(await store.read(), isNull);

    await store.write('{"key":"value"}');
    expect(await store.read(), '{"key":"value"}');
  });

  test('SharedPreferencesKeyBindingsStore honors custom key', () async {
    final store = SharedPreferencesKeyBindingsStore(key: 'custom_key_bindings');

    await store.write('custom');
    expect(await store.read(), 'custom');

    final defaultStore = SharedPreferencesKeyBindingsStore();
    expect(await defaultStore.read(), isNull);
  });
}
