import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/services/settings/settings_validator.dart';

void main() {
  group('SettingsValidator', () {
    test('clamps scale limits', () {
      expect(SettingsValidator.clampMinScale(0.0), 0.05);
      expect(SettingsValidator.clampMinScale(1.0), 0.5);
      expect(SettingsValidator.clampMaxScale(0.5), 1.0);
      expect(SettingsValidator.clampMaxScale(30.0), 20.0);
    });

    test('clamps point size and hit radius', () {
      expect(SettingsValidator.clampPointSize(1.0), 3.0);
      expect(SettingsValidator.clampPointSize(20.0), 15.0);
      expect(SettingsValidator.clampPointHitRadius(1.0), 5.0);
      expect(SettingsValidator.clampPointHitRadius(300.0), 200.0);
    });

    test('normalizes invalid scale range to defaults', () {
      final range = SettingsValidator.normalizeScaleRange(
        0.4,
        0.3,
        defaultMin: 0.05,
        defaultMax: 20.0,
      );

      expect(range.$1, 0.05);
      expect(range.$2, 20.0);
    });

    test('keeps valid scale range', () {
      final range = SettingsValidator.normalizeScaleRange(
        0.1,
        2.0,
        defaultMin: 0.05,
        defaultMax: 20.0,
      );

      expect(range.$1, 0.1);
      expect(range.$2, 2.0);
    });
  });
}
