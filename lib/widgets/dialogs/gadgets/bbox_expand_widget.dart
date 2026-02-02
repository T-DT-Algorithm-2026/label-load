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

/// 边界框扩展组件
///
/// 按比例或固定偏移量扩展标签的边界框。
class BboxExpandWidget extends StatefulWidget {
  const BboxExpandWidget({super.key});

  @override
  State<BboxExpandWidget> createState() => _BboxExpandWidgetState();
}

class _BboxExpandWidgetState extends State<BboxExpandWidget> {
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

  /// 扩展比例与偏移输入控制器。
  final _ratioXController = TextEditingController(text: '1.0');
  final _ratioYController = TextEditingController(text: '1.0');
  final _biasXController = TextEditingController(text: '0.0');
  final _biasYController = TextEditingController(text: '0.0');

  @override
  void dispose() {
    _ratioXController.dispose();
    _ratioYController.dispose();
    _biasXController.dispose();
    _biasYController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.gadgetExpand,
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.gadgetExpandDesc,
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
        const SizedBox(height: 20),
        // 参数设置
        Row(
          children: [
            Expanded(
              child: NumberField(
                label: l10n.expandRatioX,
                controller: _ratioXController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: NumberField(
                label: l10n.expandRatioY,
                controller: _ratioYController,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: NumberField(
                label: l10n.expandBiasX,
                controller: _biasXController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: NumberField(
                label: l10n.expandBiasY,
                controller: _biasYController,
              ),
            ),
          ],
        ),
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
        content: Text(l10n.bboxExpandWarning),
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
      _startExpand();
    }
  }

  /// 执行边界框扩展并更新进度与结果提示。
  Future<void> _startExpand() async {
    if (_directory == null) return;

    final ratioX = double.tryParse(_ratioXController.text) ?? 1.0;
    final ratioY = double.tryParse(_ratioYController.text) ?? 1.0;
    final biasX = double.tryParse(_biasXController.text) ?? 0.0;
    final biasY = double.tryParse(_biasYController.text) ?? 0.0;

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _status = '';
    });

    final l10n = AppLocalizations.of(context)!;
    try {
      final (success, failed) = await _gadgetService.bboxExpand(
        _directory!,
        ratioX: ratioX,
        ratioY: ratioY,
        biasX: biasX,
        biasY: biasY,
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
        details: 'bbox expand: $e',
      );
    }
  }
}
