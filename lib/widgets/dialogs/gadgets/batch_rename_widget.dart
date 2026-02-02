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

/// 批量重命名组件
///
/// 将目录中的图片按自然排序重命名为连续数字。
class BatchRenameWidget extends StatefulWidget {
  const BatchRenameWidget({super.key});

  @override
  State<BatchRenameWidget> createState() => _BatchRenameWidgetState();
}

class _BatchRenameWidgetState extends State<BatchRenameWidget> {
  /// 选中的目标目录路径。
  String? _directory;

  /// 目录下可处理文件数量。
  int _fileCount = 0;

  /// 是否正在执行批处理任务。
  bool _isProcessing = false;

  /// 当前进度（0~1）。
  double _progress = 0;

  /// 处理完成后的状态提示。
  String _status = '';

  /// 数据处理服务。
  GadgetService get _gadgetService => context.read<AppServices>().gadgetService;

  /// 目录选择服务。
  FilePickerService get _filePickerService =>
      context.read<AppServices>().filePickerService;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.gadgetRename,
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.gadgetRenameDesc,
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
            l10n.foundNImages(_fileCount),
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
          onPressed: _isProcessing || _directory == null ? null : _startRename,
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

  /// 选择目录并刷新可处理文件统计。
  Future<void> _selectDirectory() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await _filePickerService.getDirectoryPath();
      if (result != null) {
        final files = await _gadgetService.getImageFiles(result);
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

  /// 执行批量重命名并更新进度与统计信息。
  Future<void> _startRename() async {
    if (_directory == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _status = '';
    });

    final l10n = AppLocalizations.of(context)!;
    try {
      final (success, failed) = await _gadgetService.batchRename(
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

      final files = await _gadgetService.getImageFiles(_directory!);
      if (!mounted) return;
      setState(() => _fileCount = files.length);
    } catch (e, stack) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ToastUtils.showException(
        context,
        e,
        AppErrorCode.ioOperationFailed,
        l10n,
        stackTrace: stack,
        details: 'batch rename: $e',
      );
    }
  }
}
