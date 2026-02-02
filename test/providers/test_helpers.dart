import 'package:flutter/foundation.dart';

/// Temporarily overrides FlutterError.onError and restores it afterward.
Future<T> runWithFlutterErrorOverride<T>(
  FlutterExceptionHandler? handler,
  Future<T> Function() body,
) async {
  final original = FlutterError.onError;
  FlutterError.onError = handler;
  try {
    return await body();
  } finally {
    FlutterError.onError = original;
  }
}

/// Runs [body] while suppressing Flutter framework error reporting.
Future<T> runWithFlutterErrorsSuppressed<T>(Future<T> Function() body) {
  return runWithFlutterErrorOverride((_) {}, body);
}

/// Captures Flutter errors raised during [body] and returns them to the caller.
Future<T> runWithFlutterErrorsCaptured<T>(
  Future<T> Function(List<FlutterErrorDetails> errors) body,
) async {
  final errors = <FlutterErrorDetails>[];
  return runWithFlutterErrorOverride(errors.add, () => body(errors));
}
