import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readArb(String path) {
  final content = File(path).readAsStringSync();
  return jsonDecode(content) as Map<String, dynamic>;
}

Set<String> _arbKeys(Map<String, dynamic> data) {
  return data.keys.where((key) => !key.startsWith('@')).toSet();
}

void main() {
  test('ARB files share the same keys', () {
    final en = _readArb('lib/l10n/app_en.arb');
    final zh = _readArb('lib/l10n/app_zh.arb');
    expect(_arbKeys(en), _arbKeys(zh));
  });

  test('English ARB provides metadata for each key', () {
    final en = _readArb('lib/l10n/app_en.arb');
    final keys = _arbKeys(en);
    for (final key in keys) {
      final meta = en['@$key'];
      expect(meta, isA<Map>(), reason: 'Missing meta for $key');
      expect(
        (meta as Map<String, dynamic>)['description'],
        isNotEmpty,
        reason: 'Missing description for $key',
      );
    }
  });
}
