import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:label_load/services/app/app_error.dart';
import 'package:label_load/utils/toast_utils.dart';

/// Pumps a minimal app scaffold and returns its build context.
Future<BuildContext> pumpToastHost(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return ctx;
}

/// Captures FlutterError details raised during [body].
Future<({T result, FlutterErrorDetails? error})> _runWithFlutterErrorCapture<T>(
    Future<T> Function() body) async {
  FlutterErrorDetails? captured;
  final original = FlutterError.onError;
  FlutterError.onError = (details) => captured = details;
  try {
    final result = await body();
    return (result: result, error: captured);
  } finally {
    FlutterError.onError = original;
  }
}

void main() {
  testWidgets('ToastUtils.show displays message and clears previous snackbars',
      (tester) async {
    final context = await pumpToastHost(tester);

    ToastUtils.show(context, 'first');
    await tester.pump();
    expect(find.text('first'), findsOneWidget);

    ToastUtils.show(context, 'second');
    await tester.pump();
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('ToastUtils.showError shows localized AppError message',
      (tester) async {
    final context = await pumpToastHost(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    const error = AppError(AppErrorCode.imageNotSelected);

    ToastUtils.showError(context, error, l10n);
    await tester.pump();

    expect(find.text(error.message(l10n)), findsOneWidget);
  });

  testWidgets('ToastUtils.showException reports and shows fallback message',
      (tester) async {
    final context = await pumpToastHost(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final error = Exception('boom');

    final outcome = await _runWithFlutterErrorCapture(() async {
      return ToastUtils.showException(
        context,
        error,
        AppErrorCode.unexpected,
        l10n,
        details: 'detail',
      );
    });
    await tester.pump();

    expect(outcome.result.code, AppErrorCode.unexpected);
    expect(find.text(outcome.result.message(l10n)), findsOneWidget);
    expect(outcome.error, isNotNull);
  });

  testWidgets('ToastUtils.showException uses explicit message when provided',
      (tester) async {
    final context = await pumpToastHost(tester);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    final outcome = await _runWithFlutterErrorCapture(() async {
      ToastUtils.showException(
        context,
        StateError('boom'),
        AppErrorCode.ioOperationFailed,
        l10n,
        message: 'override',
      );
      return null;
    });
    await tester.pump();

    expect(find.text('override'), findsOneWidget);
    expect(outcome.error, isNotNull);
  });
}
