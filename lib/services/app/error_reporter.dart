import 'package:flutter/foundation.dart';
import 'app_error.dart';

/// Captures exceptions and normalizes them into [AppError] instances.
class ErrorReporter {
  /// Reports [error] and returns the normalized [AppError].
  ///
  /// When [error] is not an [AppError], [fallback] and [details] are used.
  static AppError report(
    Object error,
    AppErrorCode fallback, {
    StackTrace? stackTrace,
    String? details,
  }) {
    final appError = error is AppError
        ? error
        : AppError(fallback, details: details ?? error.toString());
    final trace =
        stackTrace ?? (error is Error ? error.stackTrace : StackTrace.current);

    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: trace,
        library: 'label_load',
        context: ErrorDescription('Captured AppError: ${appError.code}'),
      ),
    );

    return appError;
  }
}
