import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../models/ai_config.dart';
import '../../services/app/app_services.dart';

/// AI推理设置组件
///
/// 用于在项目设置中配置AI自动标注参数，包括模型类型、路径、阈值等。
class AiSettingsWidget extends StatefulWidget {
  /// 当前 AI 配置。
  final AiConfig config;

  /// 配置变更回调（由调用方持久化）。
  final ValueChanged<AiConfig> onChanged;

  const AiSettingsWidget({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  State<AiSettingsWidget> createState() => _AiSettingsWidgetState();
}

class _AiSettingsWidgetState extends State<AiSettingsWidget> {
  /// 关键点数量输入框控制器（仅用于姿态模型）。
  late TextEditingController _keypointsController;

  /// 类别偏移输入框控制器（用于映射外部模型类别）。
  late TextEditingController _classIdOffsetController;

  @override
  void initState() {
    super.initState();
    _keypointsController = TextEditingController(
      text: widget.config.numKeypoints > 0
          ? widget.config.numKeypoints.toString()
          : '',
    );
    _classIdOffsetController = TextEditingController(
      text: widget.config.classIdOffset.toString(),
    );
  }

  @override
  void didUpdateWidget(AiSettingsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.numKeypoints != widget.config.numKeypoints) {
      _keypointsController.text = widget.config.numKeypoints > 0
          ? widget.config.numKeypoints.toString()
          : '';
    }
    if (oldWidget.config.classIdOffset != widget.config.classIdOffset) {
      // 避免在用户正在输入时覆盖焦点
      if (_classIdOffsetController.text !=
          widget.config.classIdOffset.toString()) {
        _classIdOffsetController.text = widget.config.classIdOffset.toString();
      }
    }
  }

  @override
  void dispose() {
    _keypointsController.dispose();
    _classIdOffsetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(l10n, theme),
        const Divider(),
        const SizedBox(height: 8),
        _buildModelTypeSelector(l10n),
        if (widget.config.modelType == ModelType.yoloPose) ...[
          _buildKeypointsField(l10n, theme),
          _buildKeypointConfSlider(l10n, theme),
        ],
        _buildModelPathField(l10n, theme),
        _buildConfidenceSlider(l10n, theme),
        _buildNmsSlider(l10n, theme),
        _buildAutoInferToggle(l10n),
        const Divider(),
        _buildLabelSaveModeSelector(l10n),
      ],
    );
  }

  /// 构建标题
  Widget _buildHeader(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.smart_toy, size: 20),
            const SizedBox(width: 8),
            Text(
              l10n.aiSettings,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.aiSettingsDesc,
          style: TextStyle(fontSize: 12, color: theme.hintColor),
        ),
      ],
    );
  }

  /// 构建模型类型选择器
  Widget _buildModelTypeSelector(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.modelType,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Center(
          child: SegmentedButton<ModelType>(
            segments: [
              ButtonSegment(
                value: ModelType.yolo,
                label: Text(l10n.modelTypeYolo,
                    style: const TextStyle(fontSize: 12)),
                icon: const Icon(Icons.crop_square, size: 16),
              ),
              ButtonSegment(
                value: ModelType.yoloPose,
                label: Text(l10n.modelTypeYoloPose,
                    style: const TextStyle(fontSize: 12)),
                icon: const Icon(Icons.accessibility_new, size: 16),
              ),
            ],
            selected: {widget.config.modelType},
            onSelectionChanged: (selected) {
              widget
                  .onChanged(widget.config.copyWith(modelType: selected.first));
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 构建关键点数量输入框
  Widget _buildKeypointsField(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.numKeypoints,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _keypointsController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              hintText: '0',
              hintStyle: TextStyle(color: theme.hintColor),
            ),
            onChanged: (value) {
              final num = int.tryParse(value);
              widget.onChanged(widget.config.copyWith(numKeypoints: num ?? 0));
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.numKeypointsDesc,
          style: TextStyle(fontSize: 11, color: theme.hintColor),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 构建模型路径选择
  Widget _buildModelPathField(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.modelPath,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.config.modelPath.isEmpty
                      ? l10n.noModelSelected
                      : widget.config.modelPath.split('/').last,
                  style: TextStyle(
                    color: widget.config.modelPath.isEmpty
                        ? theme.hintColor
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: l10n.selectModel,
              onPressed: _pickModelFile,
            ),
            if (widget.config.modelPath.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                tooltip: l10n.clearModel,
                onPressed: () {
                  widget.onChanged(widget.config.copyWith(modelPath: ''));
                },
              ),
          ],
        ),
        if (widget.config.modelPath.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.config.modelPath,
              style: TextStyle(fontSize: 10, color: theme.hintColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 选择模型文件
  Future<void> _pickModelFile() async {
    final l10n = AppLocalizations.of(context)!;
    final filePicker = context.read<AppServices>().filePickerService;
    final result = await filePicker.pickFile(
      dialogTitle: l10n.selectModel,
      allowedExtensions: ['onnx'],
    );
    if (result != null) {
      widget.onChanged(widget.config.copyWith(modelPath: result));
    }
  }

  /// 构建关键点置信度阈值滑块
  Widget _buildKeypointConfSlider(AppLocalizations l10n, ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Text(l10n.keypointConfThreshold,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(
              widget.config.keypointConfThreshold.toStringAsFixed(2),
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: theme.primaryColor),
            ),
          ],
        ),
        Slider(
          value: widget.config.keypointConfThreshold,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          label: widget.config.keypointConfThreshold.toStringAsFixed(2),
          onChanged: (value) {
            widget.onChanged(
                widget.config.copyWith(keypointConfThreshold: value));
          },
        ),
      ],
    );
  }

  /// 构建置信度滑块
  Widget _buildConfidenceSlider(AppLocalizations l10n, ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Text(l10n.confidenceThreshold,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(
              widget.config.confidenceThreshold.toStringAsFixed(2),
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: theme.primaryColor),
            ),
          ],
        ),
        Slider(
          value: widget.config.confidenceThreshold,
          min: 0.05,
          max: 0.95,
          divisions: 18,
          label: widget.config.confidenceThreshold.toStringAsFixed(2),
          onChanged: (value) {
            widget
                .onChanged(widget.config.copyWith(confidenceThreshold: value));
          },
        ),
      ],
    );
  }

  /// 构建NMS阈值滑块
  Widget _buildNmsSlider(AppLocalizations l10n, ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Text(l10n.nmsThreshold,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(
              widget.config.nmsThreshold.toStringAsFixed(2),
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: theme.primaryColor),
            ),
          ],
        ),
        Slider(
          value: widget.config.nmsThreshold,
          min: 0.1,
          max: 0.9,
          divisions: 16,
          label: widget.config.nmsThreshold.toStringAsFixed(2),
          onChanged: (value) {
            widget.onChanged(widget.config.copyWith(nmsThreshold: value));
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// 构建自动推理开关
  Widget _buildAutoInferToggle(AppLocalizations l10n) {
    return SwitchListTile(
      title: Text(l10n.autoInferOnNext),
      subtitle:
          Text(l10n.autoInferOnNextDesc, style: const TextStyle(fontSize: 12)),
      value: widget.config.autoInferOnNext,
      onChanged: (value) {
        widget.onChanged(widget.config.copyWith(autoInferOnNext: value));
      },
      contentPadding: EdgeInsets.zero,
    );
  }

  /// 构建标签保存模式选择器
  Widget _buildLabelSaveModeSelector(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.labelSaveMode,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<LabelSaveMode>(
                title: Text(l10n.labelSaveModeAppend,
                    style: const TextStyle(fontSize: 14)),
                subtitle: Text(l10n.labelSaveModeAppendDesc,
                    style: const TextStyle(fontSize: 11)),
                value: LabelSaveMode.append,
                groupValue: widget.config.labelSaveMode,
                onChanged: (value) {
                  if (value != null) {
                    widget.onChanged(
                        widget.config.copyWith(labelSaveMode: value));
                  }
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            Expanded(
              child: RadioListTile<LabelSaveMode>(
                title: Text(l10n.labelSaveModeOverwrite,
                    style: const TextStyle(fontSize: 14)),
                subtitle: Text(l10n.labelSaveModeOverwriteDesc,
                    style: const TextStyle(fontSize: 11)),
                value: LabelSaveMode.overwrite,
                groupValue: widget.config.labelSaveMode,
                onChanged: (value) {
                  if (value != null) {
                    widget.onChanged(
                        widget.config.copyWith(labelSaveMode: value));
                  }
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),

        // 类别ID偏置输入框（仅在追加模式下显示）
        if (widget.config.labelSaveMode == LabelSaveMode.append) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12.0), // 稍微缩进以体现层级
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _classIdOffsetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.classIdOffset,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final offset = int.tryParse(value) ?? 0;
                      widget.onChanged(
                          widget.config.copyWith(classIdOffset: offset));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.classIdOffsetDesc,
                    style: TextStyle(
                        fontSize: 11, color: Theme.of(context).hintColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
