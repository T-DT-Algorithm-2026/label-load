import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../providers/project_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/keybindings_provider.dart';
import '../../services/app/app_services.dart';
import 'keybindings_dialog.dart';

/// 全局设置对话框
///
/// 包含主题、绘制模式、缩放范围、点大小、推理设备、快捷键、语言等设置。
class GlobalSettingsDialog extends StatefulWidget {
  const GlobalSettingsDialog({super.key});

  @override
  State<GlobalSettingsDialog> createState() => _GlobalSettingsDialogState();
}

class _GlobalSettingsDialogState extends State<GlobalSettingsDialog> {
  /// 当前语言选项（与 AppConfig.locale 保持同步）。
  late String _selectedLanguage;

  /// 自动保存开关（与 SettingsProvider 同步）。
  bool _autoSave = true;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    _selectedLanguage = provider.config.locale;
    _autoSave = settingsProvider.autoSaveOnNavigate;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: AppTheme.getCardColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 450,
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              Text(
                l10n.globalSettingsTitle,
                style: TextStyle(
                  color: AppTheme.getTextPrimary(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // 主题设置
              _buildThemeSection(l10n, themeProvider),
              const SizedBox(height: 16),

              // 框绘制模式
              _buildBoxDrawModeSection(l10n, settingsProvider),
              if (settingsProvider.isTwoClickMode) ...[
                const SizedBox(height: 8),
                _buildTwoClickModeTip(),
              ],
              const SizedBox(height: 16),

              // 缩放范围
              _buildZoomScaleSection(l10n, settingsProvider),
              const SizedBox(height: 16),

              // 图像插值
              _buildImageInterpolationSection(l10n, settingsProvider),
              const SizedBox(height: 16),

              // 点大小
              _buildPointSizeSection(l10n, settingsProvider),
              const SizedBox(height: 16),

              // 填充形状
              _buildFillShapeSection(l10n, settingsProvider),
              const SizedBox(height: 16),

              // 显示未标注点
              _buildShowUnlabeledPointsSection(l10n, settingsProvider),
              const SizedBox(height: 16),

              // 推理设备
              _buildInferenceDeviceSection(l10n, settingsProvider),
              if (settingsProvider.gpuInfo != null) ...[
                const SizedBox(height: 8),
                _buildGpuInfoSection(l10n, settingsProvider),
              ],
              const SizedBox(height: 16),

              // 快捷键设置
              _buildKeyBindingsSection(l10n),
              const SizedBox(height: 16),

              // 语言设置
              _buildLanguageSection(l10n),
              const SizedBox(height: 16),

              // 自动保存
              _buildAutoSaveSection(l10n),
              const SizedBox(height: 24),

              // 关闭按钮
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建设置卡片容器
  Widget _buildSettingsCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.getElevatedColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.getBorderColor(context)),
      ),
      child: child,
    );
  }

  /// 构建设置项标签
  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppTheme.getTextSecondary(context),
        fontSize: 13,
      ),
    );
  }

  /// 主题设置
  Widget _buildThemeSection(
      AppLocalizations l10n, ThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(l10n.theme),
        const SizedBox(height: 8),
        _buildSettingsCard(
          child: SwitchListTile(
            title: Text(
              themeProvider.isDarkMode ? l10n.darkMode : l10n.lightMode,
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
            ),
            subtitle: Text(
              l10n.themeDesc,
              style: TextStyle(
                  color: AppTheme.getTextMuted(context), fontSize: 12),
            ),
            secondary: Icon(
              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: themeProvider.isDarkMode ? Colors.amber : Colors.orange,
            ),
            value: themeProvider.isDarkMode,
            onChanged: (val) => themeProvider.toggleTheme(),
            activeColor: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  /// 框绘制模式设置
  Widget _buildBoxDrawModeSection(
      AppLocalizations l10n, SettingsProvider settingsProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(l10n.boxDrawMode),
        const SizedBox(height: 8),
        _buildSettingsCard(
          child: Column(
            children: [
              RadioListTile<BoxDrawMode>(
                title: Text(l10n.boxDrawModeDrag,
                    style: TextStyle(color: AppTheme.getTextPrimary(context))),
                subtitle: Text(l10n.boxDrawModeDragDesc,
                    style: TextStyle(
                        color: AppTheme.getTextMuted(context), fontSize: 12)),
                value: BoxDrawMode.drag,
                groupValue: settingsProvider.boxDrawMode,
                onChanged: (val) {
                  if (val != null) settingsProvider.setBoxDrawMode(val);
                },
                activeColor: AppTheme.primaryColor,
              ),
              Divider(height: 1, color: AppTheme.getBorderColor(context)),
              RadioListTile<BoxDrawMode>(
                title: Text(l10n.boxDrawModeTwoClick,
                    style: TextStyle(color: AppTheme.getTextPrimary(context))),
                subtitle: Text(l10n.boxDrawModeTwoClickDesc,
                    style: TextStyle(
                        color: AppTheme.getTextMuted(context), fontSize: 12)),
                value: BoxDrawMode.twoClick,
                groupValue: settingsProvider.boxDrawMode,
                onChanged: (val) {
                  if (val != null) settingsProvider.setBoxDrawMode(val);
                },
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 两点模式提示
  Widget _buildTwoClickModeTip() {
    final l10n = AppLocalizations.of(context)!;
    final keyBindings = context.watch<KeyBindingsProvider>();
    final moveKeyName =
        keyBindings.getMouseActionDisplayName(BindableAction.mouseMove, l10n);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.twoClickModeTip(moveKeyName),
              style: TextStyle(
                  color: AppTheme.getTextSecondary(context), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// 缩放范围设置
  Widget _buildZoomScaleSection(
      AppLocalizations l10n, SettingsProvider settingsProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(l10n.zoomScaleRange),
        const SizedBox(height: 8),
        _buildSettingsCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 最小缩放
              Row(
                children: [
                  Text(l10n.minZoom,
                      style:
                          TextStyle(color: AppTheme.getTextPrimary(context))),
                  const SizedBox(width: 8),
                  Text(
                    '${(settingsProvider.minScale * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: settingsProvider.minScale,
                min: 0.05,
                max: 0.5,
                divisions: 45,
                label:
                    '${(settingsProvider.minScale * 100).toStringAsFixed(0)}%',
                onChanged: (val) {
                  if (val < settingsProvider.maxScale) {
                    settingsProvider.setMinScale(val);
                  }
                },
                activeColor: AppTheme.primaryColor,
              ),
              const SizedBox(height: 8),
              // 最大缩放
              Row(
                children: [
                  Text(l10n.maxZoom,
                      style:
                          TextStyle(color: AppTheme.getTextPrimary(context))),
                  const SizedBox(width: 8),
                  Text(
                    '${settingsProvider.maxScale.toStringAsFixed(1)}x',
                    style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: settingsProvider.maxScale,
                min: 1.0,
                max: 20.0,
                divisions: 19,
                label: '${settingsProvider.maxScale.toStringAsFixed(1)}x',
                onChanged: (val) {
                  if (val > settingsProvider.minScale) {
                    settingsProvider.setMaxScale(val);
                  }
                },
                activeColor: AppTheme.primaryColor,
              ),
              Text(
                l10n.zoomScaleRangeDesc,
                style: TextStyle(
                    color: AppTheme.getTextMuted(context), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 点大小设置
  Widget _buildPointSizeSection(
      AppLocalizations l10n, SettingsProvider settingsProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(l10n.pointSize),
        const SizedBox(height: 8),
        _buildSettingsCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.circle,
                      size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    '${settingsProvider.pointSize.toStringAsFixed(1)} px',
                    style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: settingsProvider.pointSize,
                min: 3.0,
                max: 15.0,
                divisions: 24,
                label: '${settingsProvider.pointSize.toStringAsFixed(1)} px',
                onChanged: (val) => settingsProvider.setPointSize(val),
                activeColor: AppTheme.primaryColor,
              ),
              Text(
                l10n.pointSizeDesc,
                style: TextStyle(
                    color: AppTheme.getTextMuted(context), fontSize: 12),
              ),

              const SizedBox(height: 16),

              // 点触控范围
              Row(
                children: [
                  const Icon(Icons.ads_click,
                      size: 16, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    l10n.pointHitRadius,
                    style: TextStyle(color: AppTheme.getTextPrimary(context)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${settingsProvider.pointHitRadius.toStringAsFixed(0)} px',
                    style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: settingsProvider.pointHitRadius,
                min: 5.0,
                max: 200.0,
                divisions: 195,
                label:
                    '${settingsProvider.pointHitRadius.toStringAsFixed(0)} px',
                onChanged: (val) => settingsProvider.setPointHitRadius(val),
                activeColor: AppTheme.primaryColor,
              ),
              Text(
                l10n.pointHitRadiusDesc,
                style: TextStyle(
                    color: AppTheme.getTextMuted(context), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 图像插值设置
  Widget _buildImageInterpolationSection(
      AppLocalizations l10n, SettingsProvider settingsProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(l10n.imageInterpolation),
        const SizedBox(height: 8),
        _buildSettingsCard(
          child: SwitchListTile(
            title: Text(
              l10n.imageInterpolation,
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
            ),
            subtitle: Text(
              l10n.imageInterpolationDesc,
              style: TextStyle(
                  color: AppTheme.getTextMuted(context), fontSize: 12),
            ),
            secondary: Icon(
              settingsProvider.imageInterpolation
                  ? Icons.blur_on
                  : Icons.blur_off,
              color: settingsProvider.imageInterpolation
                  ? AppTheme.primaryColor
                  : AppTheme.getTextMuted(context),
            ),
            value: settingsProvider.imageInterpolation,
            onChanged: (val) => settingsProvider.setImageInterpolation(val),
            activeColor: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  /// 填充形状设置
  Widget _buildFillShapeSection(
      AppLocalizations l10n, SettingsProvider settingsProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(l10n.fillShape),
        const SizedBox(height: 8),
        _buildSettingsCard(
          child: SwitchListTile(
            title: Text(
              l10n.fillShape,
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
            ),
            subtitle: Text(
              l10n.fillShapeDesc,
              style: TextStyle(
                  color: AppTheme.getTextMuted(context), fontSize: 12),
            ),
            secondary: Icon(
              settingsProvider.fillShape
                  ? Icons.format_color_fill
                  : Icons.format_color_reset,
              color: settingsProvider.fillShape
                  ? AppTheme.primaryColor
                  : AppTheme.getTextMuted(context),
            ),
            value: settingsProvider.fillShape,
            onChanged: (val) => settingsProvider.setFillShape(val),
            activeColor: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  /// 显示未标注点设置
  Widget _buildShowUnlabeledPointsSection(
      AppLocalizations l10n, SettingsProvider settingsProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(l10n.showUnlabeledPoints),
        const SizedBox(height: 8),
        _buildSettingsCard(
          child: SwitchListTile(
            title: Text(
              l10n.showUnlabeledPoints,
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
            ),
            subtitle: Text(
              l10n.showUnlabeledPointsDesc,
              style: TextStyle(
                  color: AppTheme.getTextMuted(context), fontSize: 12),
            ),
            secondary: Icon(
              settingsProvider.showUnlabeledPoints
                  ? Icons.visibility
                  : Icons.visibility_off,
              color: settingsProvider.showUnlabeledPoints
                  ? AppTheme.primaryColor
                  : AppTheme.getTextMuted(context),
            ),
            value: settingsProvider.showUnlabeledPoints,
            onChanged: (val) => settingsProvider.setShowUnlabeledPoints(val),
            activeColor: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  /// 推理设备设置
  Widget _buildInferenceDeviceSection(
      AppLocalizations l10n, SettingsProvider settingsProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionLabel(l10n.inferenceDevice),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.refresh,
                  size: 18, color: AppTheme.getTextMuted(context)),
              tooltip: l10n.refreshGpuDetection,
              onPressed: () => settingsProvider.refreshGpuDetection(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildSettingsCard(
          child: Column(
            children: [
              // CPU 选项
              RadioListTile<InferenceDevice>(
                title: Text(l10n.inferenceDeviceCpu,
                    style: TextStyle(color: AppTheme.getTextPrimary(context))),
                subtitle: Text(l10n.inferenceDeviceCpuDesc,
                    style: TextStyle(
                        color: AppTheme.getTextMuted(context), fontSize: 12)),
                secondary: const Icon(Icons.computer, color: Colors.blue),
                value: InferenceDevice.cpu,
                groupValue: settingsProvider.inferenceDevice,
                onChanged: (val) {
                  if (val != null) settingsProvider.setInferenceDevice(val);
                },
                activeColor: AppTheme.primaryColor,
              ),
              Divider(height: 1, color: AppTheme.getBorderColor(context)),
              // GPU 选项
              RadioListTile<InferenceDevice>(
                title: _buildGpuOptionTitle(l10n, settingsProvider),
                subtitle: Text(
                  settingsProvider.gpuAvailable
                      ? l10n.inferenceDeviceGpuDesc
                      : l10n.gpuNotAvailableDesc,
                  style: TextStyle(
                    color: settingsProvider.gpuAvailable
                        ? AppTheme.getTextMuted(context)
                        : Colors.red.shade300,
                    fontSize: 12,
                  ),
                ),
                secondary: Icon(
                  Icons.memory,
                  color: settingsProvider.gpuAvailable
                      ? Colors.green
                      : Colors.red.shade400,
                ),
                value: InferenceDevice.gpu,
                groupValue: settingsProvider.inferenceDevice,
                onChanged: settingsProvider.gpuAvailable
                    ? (val) {
                        if (val != null) {
                          settingsProvider.setInferenceDevice(val);
                        }
                      }
                    : null,
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// GPU 选项标题（含状态标签）。
  Widget _buildGpuOptionTitle(
      AppLocalizations l10n, SettingsProvider settingsProvider) {
    return Row(
      children: [
        Text(
          l10n.inferenceDeviceGpu,
          style: TextStyle(
            color: settingsProvider.gpuAvailable
                ? AppTheme.getTextPrimary(context)
                : Colors.red.shade400,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: settingsProvider.gpuAvailable
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: settingsProvider.gpuAvailable
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.red.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            settingsProvider.gpuAvailable
                ? l10n.gpuDetected
                : l10n.gpuNotAvailable,
            style: TextStyle(
              color: settingsProvider.gpuAvailable
                  ? Colors.green.shade400
                  : Colors.red.shade400,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  /// GPU 信息显示。
  Widget _buildGpuInfoSection(
      AppLocalizations l10n, SettingsProvider settingsProvider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.getElevatedColor(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppTheme.getBorderColor(context).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 14, color: AppTheme.getTextMuted(context)),
              const SizedBox(width: 8),
              Text(
                l10n.deviceInfo,
                style: TextStyle(
                  color: AppTheme.getTextSecondary(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            settingsProvider.gpuInfo!.deviceName,
            style:
                TextStyle(color: AppTheme.getTextMuted(context), fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            '${l10n.availableProviders}: ${settingsProvider.availableProviders}',
            style:
                TextStyle(color: AppTheme.getTextMuted(context), fontSize: 10),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  /// 快捷键设置
  Widget _buildKeyBindingsSection(AppLocalizations l10n) {
    final services = context.read<AppServices>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(l10n.keyBindings),
        const SizedBox(height: 8),
        _buildSettingsCard(
          child: ListTile(
            leading: const Icon(Icons.keyboard, color: AppTheme.primaryColor),
            title: Text(l10n.keyBindingsTitle,
                style: TextStyle(color: AppTheme.getTextPrimary(context))),
            subtitle: Text(l10n.keyBindingsDesc,
                style: TextStyle(
                    color: AppTheme.getTextMuted(context), fontSize: 12)),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 16, color: AppTheme.getTextMuted(context)),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => KeyBindingsDialog(
                  sideButtonService: services.sideButtonService,
                  keyboardStateReader: services.keyboardStateReader,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 语言设置（更新项目配置中的 locale）。
  Widget _buildLanguageSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(l10n.language),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.getElevatedColor(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.getBorderColor(context)),
          ),
          child: PopupMenuButton<String>(
            initialValue: _selectedLanguage,
            offset: const Offset(0, 40),
            onSelected: (val) {
              setState(() => _selectedLanguage = val);
              // 持久化到项目配置。
              context.read<ProjectProvider>().setLocale(val);
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'en', child: Text(l10n.english)),
              PopupMenuItem(value: 'zh', child: Text(l10n.chinese)),
            ],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedLanguage == 'zh' ? l10n.chinese : l10n.english,
                  style: TextStyle(color: AppTheme.getTextPrimary(context)),
                ),
                Icon(Icons.arrow_drop_down,
                    color: AppTheme.getTextMuted(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 自动保存设置（同步写入 SettingsProvider）。
  Widget _buildAutoSaveSection(AppLocalizations l10n) {
    return _buildSettingsCard(
      child: SwitchListTile(
        title: Text(l10n.autoSave,
            style: TextStyle(color: AppTheme.getTextPrimary(context))),
        subtitle: Text(l10n.autoSaveDesc,
            style:
                TextStyle(color: AppTheme.getTextMuted(context), fontSize: 12)),
        value: _autoSave,
        onChanged: (val) {
          setState(() => _autoSave = val);
          context.read<SettingsProvider>().setAutoSaveOnNavigate(val);
        },
        activeColor: AppTheme.primaryColor,
      ),
    );
  }
}
