import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:label_load/services/app/app_error.dart';
import 'package:label_load/services/app/error_reporter.dart';

void main() {
  test('ErrorReporter wraps non-AppError with fallback', () {
    final originalHandler = FlutterError.onError;
    FlutterError.onError = (details) {};
    addTearDown(() => FlutterError.onError = originalHandler);

    final appError = ErrorReporter.report(
      Exception('boom'),
      AppErrorCode.unexpected,
      details: 'context',
    );

    expect(appError.code, AppErrorCode.unexpected);
    expect(appError.details, 'context');
  });

  test('ErrorReporter returns existing AppError', () {
    final originalHandler = FlutterError.onError;
    FlutterError.onError = (details) {};
    addTearDown(() => FlutterError.onError = originalHandler);

    const input = AppError(AppErrorCode.aiModelNotLoaded);
    final appError = ErrorReporter.report(input, AppErrorCode.unexpected);

    expect(appError, input);
  });
}
