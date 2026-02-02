import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// 统一错误码
enum AppErrorCode {
  projectNotLoaded,
  aiModelNotConfigured,
  aiModelLoadFailed,
  imageNotSelected,
  aiInferenceFailed,
  projectListLoadFailed,
  projectListSaveFailed,
  projectLoadFailed,
  imageFileNotFound,
  imageDecodeFailed,
  aiModelNotLoaded,
  ioOperationFailed,
  unexpected,
  labelLineEmpty,
  labelInvalidClassId,
  labelInvalidPolygon,
  labelInvalidBox,
  unsavedChanges,
}

/// 应用错误
class AppError {
  /// 错误码（用于映射本地化文案）
  final AppErrorCode code;

  /// 可选的详细信息（用于带占位符的错误消息）
  final String? details;

  const AppError(this.code, {this.details});

  /// 获取本地化错误消息
  String message(AppLocalizations l10n) {
    switch (code) {
      case AppErrorCode.projectNotLoaded:
        return l10n.errorProjectNotLoaded;
      case AppErrorCode.aiModelNotConfigured:
        return l10n.errorAiModelNotConfigured;
      case AppErrorCode.aiModelLoadFailed:
        return l10n.errorAiModelLoadFailed;
      case AppErrorCode.imageNotSelected:
        return l10n.errorImageNotSelected;
      case AppErrorCode.aiInferenceFailed:
        return l10n.errorAiInferenceFailed(details ?? '');
      case AppErrorCode.projectListLoadFailed:
        return l10n.errorProjectListLoadFailed(details ?? '');
      case AppErrorCode.projectListSaveFailed:
        return l10n.errorProjectListSaveFailed(details ?? '');
      case AppErrorCode.projectLoadFailed:
        return l10n.errorProjectLoadFailed(details ?? '');
      case AppErrorCode.imageFileNotFound:
        return l10n.errorImageFileNotFound(details ?? '');
      case AppErrorCode.imageDecodeFailed:
        return l10n.errorImageDecodeFailed;
      case AppErrorCode.aiModelNotLoaded:
        return l10n.errorAiModelNotLoaded;
      case AppErrorCode.ioOperationFailed:
        return l10n.errorIoOperationFailed(details ?? '');
      case AppErrorCode.unexpected:
        return l10n.errorUnexpected(details ?? '');
      case AppErrorCode.labelLineEmpty:
        return l10n.errorLabelLineEmpty;
      case AppErrorCode.labelInvalidClassId:
        return l10n.errorLabelInvalidClassId(details ?? '');
      case AppErrorCode.labelInvalidPolygon:
        return l10n.errorLabelInvalidPolygon(details ?? '');
      case AppErrorCode.labelInvalidBox:
        return l10n.errorLabelInvalidBox(details ?? '');
      case AppErrorCode.unsavedChanges:
        return l10n.errorUnsavedChanges;
    }
  }
}
