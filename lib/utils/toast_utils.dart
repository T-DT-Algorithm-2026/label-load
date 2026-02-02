import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app/theme.dart';
import '../services/app/app_error.dart';
import '../services/app/error_reporter.dart';

/// 消息提示工具类
///
/// 用于显示短时间的浮动消息，并自动处理消息堆叠问题。
class ToastUtils {
  /// 显示消息
  ///
  /// [context] 上下文
  /// [message] 消息内容
  /// [duration] 显示时长，默认为 500ms
  static void show(BuildContext context, String message,
      {Duration duration = const Duration(milliseconds: 500)}) {
    // 在显示新消息前清除当前正在显示或排队的消息，防止堆叠。
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.getElevatedColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.getBorderColor(context)),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
            child: Text(message,
                style: TextStyle(color: AppTheme.getTextPrimary(context))),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left: 20,
          bottom: 20,
          right: MediaQuery.of(context).size.width * 0.6,
        ),
        padding: EdgeInsets.zero,
        duration: duration,
      ),
    );
  }

  /// 显示 AppError 的本地化消息
  static void showError(
    BuildContext context,
    AppError error,
    AppLocalizations l10n, {
    Duration duration = const Duration(milliseconds: 500),
  }) {
    show(context, error.message(l10n), duration: duration);
  }

  /// 上报异常并显示统一错误提示
  ///
  /// 返回规范化后的 [AppError] 以便调用方做进一步处理。
  static AppError showException(
    BuildContext context,
    Object error,
    AppErrorCode fallback,
    AppLocalizations l10n, {
    StackTrace? stackTrace,
    String? details,
    String? message,
    Duration duration = const Duration(milliseconds: 500),
  }) {
    final appError = ErrorReporter.report(
      error,
      fallback,
      stackTrace: stackTrace,
      details: details,
    );
    if (message != null) {
      show(context, message, duration: duration);
    } else {
      showError(context, appError, l10n, duration: duration);
    }
    return appError;
  }
}
