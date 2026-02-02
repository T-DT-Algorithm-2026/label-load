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

/// XYXY转XYWH组件
///
/// 将标签坐标从 (x1,y1,x2,y2) 格式转换为 (cx,cy,w,h) 格式。
class Xyxy2XywhWidget extends StatefulWidget {
  const Xyxy2XywhWidget({super.key});

  @override
  State<Xyxy2XywhWidget> createState() => _Xyxy2XywhWidgetState();
}

class _Xyxy2XywhWidgetState extends State<Xyxy2XywhWidget> {
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
          l10n.gadgetCoord,
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.gadgetCoordDesc,
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
          onPressed:
              _isProcessing || _directory == null ? null : _showWarningAndStart,
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

  /// 显示风险提示，确认后启动处理。
  Future<void> _showWarningAndStart() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Text(l10n.warning),
          ],
        ),
        content: Text(l10n.xyxyWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _startConvert();
    }
  }

  /// 执行坐标转换并更新进度与结果提示。
  Future<void> _startConvert() async {
    if (_directory == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _status = '';
    });

    final l10n = AppLocalizations.of(context)!;
    try {
      final (success, failed) = await _gadgetService.xyxy2xywh(
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
        details: 'xyxy2xywh: $e',
      );
    }
  }
}
