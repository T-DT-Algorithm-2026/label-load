import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/providers/app_error_state.dart';
import 'package:label_load/services/app/app_error.dart';

import 'test_helpers.dart';

class ErrorStateHarness extends ChangeNotifier with AppErrorState {
  void setErrorValue(AppError? error, {bool notify = true}) {
    setError(error, notify: notify);
  }

  void clearErrorValue({bool notify = true}) {
    clearError(notify: notify);
  }

  AppError reportErrorValue(Object error, AppErrorCode fallback) {
    return reportError(error, fallback);
  }
}

void main() {
  group('AppErrorState', () {
    test('setError and clearError update state and notify', () {
      final harness = ErrorStateHarness();
      var notifyCount = 0;
      harness.addListener(() => notifyCount += 1);

      harness.setErrorValue(const AppError(AppErrorCode.unexpected));
      expect(harness.error, isNotNull);
      expect(notifyCount, 1);

      harness.clearErrorValue(notify: true);
      expect(harness.error, isNull);
      expect(notifyCount, 2);
    });

    test('clearError can skip notifications', () {
      final harness = ErrorStateHarness();
      var notifyCount = 0;
      harness.addListener(() => notifyCount += 1);

      harness.setErrorValue(const AppError(AppErrorCode.unexpected));
      harness.clearErrorValue(notify: false);

      expect(harness.error, isNull);
      expect(notifyCount, 1);
    });

    test('reportError wraps exception and sets error', () async {
      final harness = ErrorStateHarness();
      await runWithFlutterErrorsSuppressed(() async {
        final error = harness.reportErrorValue(
          Exception('boom'),
          AppErrorCode.ioOperationFailed,
        );

        expect(error.code, AppErrorCode.ioOperationFailed);
        expect(harness.error, isNotNull);
      });
    });
  });
}
