import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/services/settings/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('SharedPreferencesStore reads and writes scalar values', () async {
    final store = SharedPreferencesStore();

    await store.setInt('intKey', 42);
    await store.setDouble('doubleKey', 3.14);
    await store.setBool('boolKey', true);

    expect(await store.getInt('intKey'), 42);
    expect(await store.getDouble('doubleKey'), 3.14);
    expect(await store.getBool('boolKey'), true);
  });

  test('SharedPreferencesStore returns null for missing keys', () async {
    final store = SharedPreferencesStore();

    expect(await store.getInt('missingInt'), isNull);
    expect(await store.getDouble('missingDouble'), isNull);
    expect(await store.getBool('missingBool'), isNull);
  });
}
