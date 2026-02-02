import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/app/theme.dart';
import 'package:label_load/models/label_definition.dart';

/// Builds a theme-backed context and captures AppTheme colors.
Future<Map<String, Color>> _captureColors(
  WidgetTester tester,
  ThemeData theme,
) async {
  final completer = Completer<Map<String, Color>>();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) {
          completer.complete({
            'background': AppTheme.getBackground(context),
            'card': AppTheme.getCardColor(context),
            'elevated': AppTheme.getElevatedColor(context),
            'overlay': AppTheme.getOverlayColor(context),
            'textPrimary': AppTheme.getTextPrimary(context),
            'textSecondary': AppTheme.getTextSecondary(context),
            'textMuted': AppTheme.getTextMuted(context),
            'border': AppTheme.getBorderColor(context),
          });
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pump();
  return completer.future;
}

void main() {
  test('AppTheme.getLabelColor uses palette modulo', () {
    const base = LabelPalettes.defaultPalette;
    expect(AppTheme.getLabelColor(0), base[0]);
    expect(AppTheme.getLabelColor(base.length), base[0]);
    expect(AppTheme.getLabelColor(base.length + 2), base[2]);
  });

  testWidgets('AppTheme light getters reflect light colors', (tester) async {
    final colors = await _captureColors(
      tester,
      ThemeData(brightness: Brightness.light),
    );

    expect(colors['background'], AppTheme.bgLightBase);
    expect(colors['card'], AppTheme.bgLightCard);
    expect(colors['elevated'], AppTheme.bgLightElevated);
    expect(colors['overlay'], AppTheme.bgLightOverlay);
    expect(colors['textPrimary'], AppTheme.textLightPrimary);
    expect(colors['textSecondary'], AppTheme.textLightSecondary);
    expect(colors['textMuted'], AppTheme.textLightMuted);
    expect(colors['border'], AppTheme.borderLightDefault);
  });

  testWidgets('AppTheme dark getters reflect dark colors', (tester) async {
    final colors = await _captureColors(
      tester,
      ThemeData(brightness: Brightness.dark),
    );

    expect(colors['background'], AppTheme.bgDark);
    expect(colors['card'], AppTheme.bgCard);
    expect(colors['elevated'], AppTheme.bgElevated);
    expect(colors['overlay'], AppTheme.bgOverlay);
    expect(colors['textPrimary'], AppTheme.textPrimary);
    expect(colors['textSecondary'], AppTheme.textSecondary);
    expect(colors['textMuted'], AppTheme.textMuted);
    expect(colors['border'], AppTheme.borderDefault);
  });

  test('AppTheme lightTheme and darkTheme expose core settings', () {
    final light = AppTheme.lightTheme;
    final dark = AppTheme.darkTheme;

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.colorScheme.primary, AppTheme.primaryColor);
    expect(dark.colorScheme.primary, AppTheme.primaryColor);
    expect(light.colorScheme.secondary, AppTheme.secondaryColor);
    expect(dark.colorScheme.secondary, AppTheme.secondaryColor);
    expect(light.colorScheme.surface, AppTheme.bgLightCard);
    expect(dark.colorScheme.surface, AppTheme.bgCard);
  });
}
