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

/// 标签转换组件
///
/// 将标签的类别ID映射到新的类别定义。
class ConvertLabelsWidget extends StatefulWidget {
  const ConvertLabelsWidget({super.key});

  @override
  State<ConvertLabelsWidget> createState() => _ConvertLabelsWidgetState();
}

class _ConvertLabelsWidgetState extends State<ConvertLabelsWidget> {
  /// 源标签目录。
  String? _sourceDir;

  /// 目标 classes.txt 文件路径。
  String? _targetClassesFile;

  /// 源类别列表。
  List<String> _sourceClasses = [];

  /// 目标类别列表。
  List<String> _targetClasses = [];

  /// 源类别到目标类别的映射表（索引）。
  List<int> _mapping = [];

  /// 是否正在执行转换。
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
          l10n.gadgetConvert,
          style: TextStyle(
            color: AppTheme.getTextPrimary(context),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.gadgetConvertDesc,
          style: TextStyle(
            color: AppTheme.getTextMuted(context),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),
        DirectorySelector(
          label: l10n.inputDir,
          value: _sourceDir,
          onSelect: _selectSourceDir,
        ),
        const SizedBox(height: 12),
        FileSelector(
          label: l10n.gadgetTargetClasses,
          value: _targetClassesFile,
          onSelect: _selectTargetClasses,
        ),
        const SizedBox(height: 16),
        // 类别映射
        if (_sourceClasses.isNotEmpty && _targetClasses.isNotEmpty) ...[
          Text(
            l10n.gadgetClassMapping,
            style: TextStyle(
              color: AppTheme.getTextPrimary(context),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildMappingList(l10n),
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
          onPressed: _isProcessing || _sourceDir == null || _mapping.isEmpty
              ? null
              : _startConvert,
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

  /// 构建类别映射列表
  Widget _buildMappingList(AppLocalizations l10n) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.getBorderColor(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        itemCount: _sourceClasses.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$index: ${_sourceClasses[index]}',
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward,
                    size: 16, color: AppTheme.getTextMuted(context)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<int>(
                    value: _mapping[index],
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: -1,
                        child: Text(
                          l10n.gadgetMappingDelete,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                      ..._targetClasses.asMap().entries.map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text('${e.key}: ${e.value}',
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ),
                    ],
                    onChanged: (value) {
                      setState(() => _mapping[index] = value ?? -1);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 选择源目录并加载 classes.txt 生成映射。
  Future<void> _selectSourceDir() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await _filePickerService.getDirectoryPath();
      if (result != null) {
        final classes = await _gadgetService.readClassNames(result);
        setState(() {
          _sourceDir = result;
          _sourceClasses = classes;
          _mapping = List.generate(classes.length, (i) => _autoMap(classes[i]));
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
          details: 'read classes: $e',
        );
      }
    }
  }

  /// 选择目标 classes.txt 并刷新映射列表。
  Future<void> _selectTargetClasses() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await _filePickerService.pickFile(
        allowedExtensions: ['txt'],
      );
      if (result != null) {
        final classes = await _gadgetService.readLines(result);
        setState(() {
          _targetClassesFile = result;
          _targetClasses = classes;
          _mapping = List.generate(
              _sourceClasses.length, (i) => _autoMap(_sourceClasses[i]));
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
          details: 'load target classes: $e',
        );
      }
    }
  }

  /// 自动匹配类别
  int _autoMap(String sourceName) {
    // 精确匹配
    final index = _targetClasses
        .indexWhere((t) => t.toLowerCase() == sourceName.toLowerCase());
    if (index >= 0) return index;

    // 部分匹配
    final partialIndex = _targetClasses.indexWhere((t) =>
        t.toLowerCase().contains(sourceName.toLowerCase()) ||
        sourceName.toLowerCase().contains(t.toLowerCase()));
    if (partialIndex >= 0) return partialIndex;

    return -1;
  }

  /// 执行类别映射转换并更新进度与结果。
  Future<void> _startConvert() async {
    if (_sourceDir == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0;
      _status = '';
    });

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      final (success, failed) = await _gadgetService.convertLabels(
        _sourceDir!,
        _mapping,
        onProgress: (current, total) {
          setState(() => _progress = current / total);
        },
      );

      await _gadgetService.writeClassNames(_sourceDir!, _targetClasses);

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
        details: 'convert labels: $e',
      );
    }
  }
}
