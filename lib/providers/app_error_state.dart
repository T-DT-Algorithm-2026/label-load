import 'package:flutter/foundation.dart';
import '../services/app/app_error.dart';
import '../services/app/error_reporter.dart';

/// 统一的错误状态与上报封装。
///
/// 负责维护当前错误状态，并提供标准化的上报/清除能力。
/// 搭配 [ChangeNotifier] 使用，可选择是否触发监听更新。
mixin AppErrorState on ChangeNotifier {
  AppError? _error;

  /// 当前错误（无错误时为 null）。
  AppError? get error => _error;

  /// 清除错误。
  ///
  /// [notify] 为 true 时通知监听者。
  @protected
  void clearError({bool notify = false}) {
    _error = null;
    if (notify) {
      notifyListeners();
    }
  }

  /// 设置错误。
  ///
  /// [notify] 为 true 时通知监听者。
  @protected
  void setError(AppError? error, {bool notify = true}) {
    _error = error;
    if (notify) {
      notifyListeners();
    }
  }

  /// 上报错误并更新错误状态。
  ///
  /// 返回封装后的 [AppError]，并按需通知监听者。
  @protected
  AppError reportError(
    Object error,
    AppErrorCode fallback, {
    StackTrace? stackTrace,
    String? details,
    bool notify = true,
  }) {
    final appError = ErrorReporter.report(
      error,
      fallback,
      stackTrace: stackTrace,
      details: details,
    );
    _error = appError;
    if (notify) {
      notifyListeners();
    }
    return appError;
  }
}
