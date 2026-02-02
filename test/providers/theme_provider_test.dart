import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/providers/theme_provider.dart';
import 'package:label_load/services/settings/theme_store.dart';

import 'test_helpers.dart';

class FakeThemeStore implements ThemeStore {
  bool? readValue;
  bool? lastWritten;
  int readCount = 0;

  @override
  Future<bool?> readIsDark() async {
    readCount += 1;
    return readValue;
  }

  @override
  Future<void> writeIsDark(bool value) async {
    lastWritten = value;
  }
}

class ThrowingThemeStore implements ThemeStore {
  @override
  Future<bool?> readIsDark() async {
    throw Exception('read failed');
  }

  @override
  Future<void> writeIsDark(bool value) async {
    throw Exception('write failed');
  }
}

void main() {
  test('ThemeProvider loads and saves via store', () async {
    final store = FakeThemeStore()..readValue = false;
    final provider = ThemeProvider(store: store);

    await Future<void>.delayed(Duration.zero);

    expect(store.readCount, 1);
    expect(provider.themeMode, ThemeMode.light);
    expect(provider.isInitialized, isTrue);
    expect(provider.isDarkMode, isFalse);

    await provider.toggleTheme();
    expect(provider.themeMode, ThemeMode.dark);
    expect(store.lastWritten, true);
  });

  test('ThemeProvider setThemeMode updates and skips no-op', () async {
    final store = FakeThemeStore()..readValue = true;
    final provider = ThemeProvider(store: store);

    await Future<void>.delayed(Duration.zero);
    expect(provider.isDarkMode, isTrue);

    await provider.setThemeMode(ThemeMode.light);
    expect(provider.themeMode, ThemeMode.light);
    expect(provider.isDarkMode, isFalse);
    expect(store.lastWritten, isFalse);

    store.lastWritten = null;
    await provider.setThemeMode(ThemeMode.light);
    expect(store.lastWritten, isNull);
  });

  test('ThemeProvider falls back on read error', () async {
    await runWithFlutterErrorsSuppressed(() async {
      final provider = ThemeProvider(store: ThrowingThemeStore());

      await Future<void>.delayed(Duration.zero);

      expect(provider.themeMode, ThemeMode.dark);
      expect(provider.error, isNotNull);
    });
  });

  test('ThemeProvider reports save error', () async {
    await runWithFlutterErrorsSuppressed(() async {
      final store = ThrowingThemeStore();
      final provider = ThemeProvider(store: store);

      await Future<void>.delayed(Duration.zero);
      await provider.toggleTheme();

      expect(provider.error, isNotNull);
    });
  });
}
