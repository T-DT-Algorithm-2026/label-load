import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:label_load/services/app/app_error.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppError maps codes to localized messages', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    const detail = 'detail';

    final cases = <AppErrorCode, String Function(AppLocalizations)>{
      AppErrorCode.projectNotLoaded: (l) => l.errorProjectNotLoaded,
      AppErrorCode.aiModelNotConfigured: (l) => l.errorAiModelNotConfigured,
      AppErrorCode.aiModelLoadFailed: (l) => l.errorAiModelLoadFailed,
      AppErrorCode.imageNotSelected: (l) => l.errorImageNotSelected,
      AppErrorCode.aiInferenceFailed: (l) => l.errorAiInferenceFailed(detail),
      AppErrorCode.projectListLoadFailed: (l) =>
          l.errorProjectListLoadFailed(detail),
      AppErrorCode.projectListSaveFailed: (l) =>
          l.errorProjectListSaveFailed(detail),
      AppErrorCode.projectLoadFailed: (l) => l.errorProjectLoadFailed(detail),
      AppErrorCode.imageFileNotFound: (l) => l.errorImageFileNotFound(detail),
      AppErrorCode.imageDecodeFailed: (l) => l.errorImageDecodeFailed,
      AppErrorCode.aiModelNotLoaded: (l) => l.errorAiModelNotLoaded,
      AppErrorCode.ioOperationFailed: (l) => l.errorIoOperationFailed(detail),
      AppErrorCode.unexpected: (l) => l.errorUnexpected(detail),
      AppErrorCode.labelLineEmpty: (l) => l.errorLabelLineEmpty,
      AppErrorCode.labelInvalidClassId: (l) =>
          l.errorLabelInvalidClassId(detail),
      AppErrorCode.labelInvalidPolygon: (l) =>
          l.errorLabelInvalidPolygon(detail),
      AppErrorCode.labelInvalidBox: (l) => l.errorLabelInvalidBox(detail),
      AppErrorCode.unsavedChanges: (l) => l.errorUnsavedChanges,
    };

    for (final entry in cases.entries) {
      final error = AppError(entry.key, details: detail);
      expect(error.message(l10n), entry.value(l10n));
    }
  });
}
