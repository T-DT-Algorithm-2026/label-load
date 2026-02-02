import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../services/app/app_services.dart';
import '../../../services/gadgets/gadget_service.dart';
import '../../../services/files/file_picker_service.dart';
import '../../../services/app/app_error.dart';
import '../../../utils/toast_utils.dart';
import 'gadget_common.dart';

/// 删除关键点组件
///
/// 从标签文件中删除所有关键点数据，只保留边界框。
class DeleteKeypointsWidget extends StatefulWidget {
  const DeleteKeypointsWidget({super.key});

  @override
  State<DeleteKeypointsWidget> createState() => _DeleteKeypointsWidgetState();
}

class _DeleteKeypointsWidgetState extends State<DeleteKeypointsWidget> {
  /// 选中的标签目录。
  String? _directory;

  /// 标签文件数量。
  int _fileCount = 0;

  /// 是否正在执行处理。
  bool _isProcessing = false;

  /// 当前进度（0~1）。
  double _progress = 0;

  /// 处理结果提示文本。
  String _status = '';

  /// 工具服务。
  GadgetService get _gadgetService => context.read<AppServices>().gadgetService;

  /// 文件选择服务。
  FilePickerService get _filePickerService =>
      context.read<AppServices>().filePickerService;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.gadgetPointDelete,
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.gadgetPointDeleteDesc,
          style: TextStyle(
            color: AppTheme.getTextMuted(context),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),
        DirectorySelector(
          label: l10n.targetDir,
          value: _directory,
          onSelect: _selectDirectory,
        ),
        if (_fileCount > 0) ...[
          const SizedBox(height: 8),
          Text(
            l10n.foundNLabels(_fileCount),
            style: TextStyle(
                color: AppTheme.getTextSecondary(context), fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        if (_isProcessing) ...[
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 8),
        ],
        if (_status.isNotEmpty) ...[
          Text(_status,
              style: TextStyle(color: AppTheme.getTextSecondary(context))),
          const SizedBox(height: 16),
        ],
        ElevatedButton.icon(
          onPressed: _isProcessing || _directory == null ? null : _startDelete,
          icon: const Icon(Icons.play_arrow),
          label: Text(_isProcessing ? l10n.processing : l10n.startProcess),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  /// 选择目录并刷新标签文件数量。
  Future<void> _selectDirectory() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await _filePickerService.getDirectoryPath();
      if (result != null) {
        final files = await _gadgetService.getLabelFiles(result);
        setState(() {
          _directory = result;
          _fileCount = files.length;
          _status = '';
        });
      }
    } catch (e, stack) {
      if (mounted) {
        ToastUtils.showException(
          context,
          e,
          AppErrorCode.ioOperationFailed,
          l10n,
          stackTrace: stack,
          details: 'select directory: $e',
        );
      }
    }
  }

  /// 批量删除关键点并更新进度与结果提示。
  Future<void> _startDelete() async {
    if (_directory == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _status = '';
    });

    final l10n = AppLocalizations.of(context)!;
    try {
      final (success, failed) = await _gadgetService.deleteKeypoints(
        _directory!,
        onProgress: (current, total) {
          setState(() => _progress = current / total);
        },
      );

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _status = l10n.successNFailedM(success, failed);
      });
    } catch (e, stack) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ToastUtils.showException(
        context,
        e,
        AppErrorCode.ioOperationFailed,
        l10n,
        stackTrace: stack,
        details: 'delete keypoints: $e',
      );
    }
  }
}
