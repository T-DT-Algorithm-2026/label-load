import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../app/theme.dart';
import '../models/label.dart';
import '../providers/project_provider.dart';
import '../providers/canvas_provider.dart';
import '../providers/keybindings_provider.dart';
import '../providers/settings_provider.dart';
import '../services/input/side_button_service.dart';
import '../services/input/input_action_gate.dart';
import '../services/input/keyboard_state_reader.dart';
import '../services/app/app_error.dart';
import '../services/app/app_services.dart';
import '../widgets/canvas/image_canvas.dart';
import '../widgets/sidebar/sidebar.dart';
import '../widgets/toolbar/main_toolbar.dart';
import '../providers/project_list_provider.dart';
import '../utils/toast_utils.dart';

/// 主标注页面
///
/// 包含工具栏、图像画布和侧边栏，处理全局键盘快捷键。
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.sideButtonService,
    this.inputActionGate,
    this.keyboardStateReader,
  });

  /// 注入侧键服务，便于测试或替换默认实现。
  final SideButtonService? sideButtonService;

  /// 注入输入去重门控器，便于测试或替换默认实现。
  final InputActionGate? inputActionGate;

  /// 注入键盘状态读取器，便于测试或替换默认实现。
  final KeyboardStateReader? keyboardStateReader;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FocusNode _focusNode = FocusNode();
  StreamSubscription<SideButtonEvent>? _sideButtonSub;
  late final InputActionGate _inputActionGate;
  late final SideButtonService _sideButtonService;
  late final KeyboardStateReader _keyboardStateReader;

  @override
  void dispose() {
    _focusNode.dispose();
    _sideButtonSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final services = context.read<AppServices>();
    _inputActionGate = widget.inputActionGate ?? services.inputActionGate;
    _sideButtonService = widget.sideButtonService ?? services.sideButtonService;
    _keyboardStateReader =
        widget.keyboardStateReader ?? services.keyboardStateReader;
    // 监听项目配置变更（如位置记录、AI状态更新）并持久化
    context.read<ProjectProvider>().addListener(_onProjectProviderChange);
    _sideButtonSub = _sideButtonService.stream.listen(_handleSideButtonStream);
  }

  /// 监听项目配置变更并触发列表持久化。
  void _onProjectProviderChange() {
    if (!mounted) return;
    final projectProvider = context.read<ProjectProvider>();
    final update = projectProvider.pendingConfigUpdate;
    if (update != null) {
      context.read<ProjectListProvider>().updateProject(update);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePointerDown,
        child: Focus(
          focusNode: _focusNode,
          autofocus: false,
          canRequestFocus: true,
          onKeyEvent: (node, event) {
            _handleKeyEvent(event);
            return KeyEventResult.ignored;
          },
          child: Column(
            children: [
              const MainToolbar(),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        color: AppTheme.getBackground(context),
                        child: ImageCanvas(
                          sideButtonService: _sideButtonService,
                          inputActionGate: _inputActionGate,
                          keyboardStateReader: _keyboardStateReader,
                        ),
                      ),
                    ),
                    const Sidebar(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 处理键盘事件
  void _handleKeyEvent(KeyEvent event) {
    final keyBindings = context.read<KeyBindingsProvider>();
    if (event is! KeyDownEvent) return;
    final sideAction = keyBindings.getActionForSideButtonKey(event.logicalKey);
    if (sideAction != null) {
      _handleHomeActionFromSource(sideAction, InputSource.keyboard);
      return;
    }

    // 上一张图片
    if (keyBindings.matchesKeyEvent(BindableAction.prevImage, event)) {
      _handleHomeActionFromSource(
          BindableAction.prevImage, InputSource.keyboard);
      return;
    }

    // 下一张图片
    if (keyBindings.matchesKeyEvent(BindableAction.nextImage, event)) {
      _handleHomeActionFromSource(
          BindableAction.nextImage, InputSource.keyboard);
      return;
    }

    // 上一个标签
    if (keyBindings.matchesKeyEvent(BindableAction.prevLabel, event)) {
      _handleHomeActionFromSource(
          BindableAction.prevLabel, InputSource.keyboard);
      return;
    }

    // 下一个标签
    if (keyBindings.matchesKeyEvent(BindableAction.nextLabel, event)) {
      _handleHomeActionFromSource(
          BindableAction.nextLabel, InputSource.keyboard);
      return;
    }

    // 删除选中标签
    if (keyBindings.matchesKeyEvent(BindableAction.deleteSelected, event)) {
      _handleHomeActionFromSource(
          BindableAction.deleteSelected, InputSource.keyboard);
      return;
    }

    // Backspace也支持删除
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _handleHomeActionFromSource(
          BindableAction.deleteSelected, InputSource.keyboard);
      return;
    }

    // 切换标注模式
    if (keyBindings.matchesKeyEvent(BindableAction.toggleMode, event)) {
      _handleHomeActionFromSource(
          BindableAction.toggleMode, InputSource.keyboard);
      return;
    }

    // 保存
    if (keyBindings.matchesKeyEvent(BindableAction.save, event)) {
      _handleHomeActionFromSource(BindableAction.save, InputSource.keyboard);
      return;
    }

    // 切换暗部增强
    if (keyBindings.matchesKeyEvent(BindableAction.toggleDarkEnhance, event)) {
      _handleHomeActionFromSource(
          BindableAction.toggleDarkEnhance, InputSource.keyboard);
      return;
    }

    // AI推理
    if (keyBindings.matchesKeyEvent(BindableAction.aiInference, event)) {
      _handleHomeActionFromSource(
          BindableAction.aiInference, InputSource.keyboard);
      return;
    }

    // 切换关键点可见性
    if (keyBindings.matchesKeyEvent(BindableAction.toggleVisibility, event)) {
      _handleHomeActionFromSource(
          BindableAction.toggleVisibility, InputSource.keyboard);
      return;
    }
  }

  /// 处理鼠标按键事件（映射为绑定动作）。
  void _handlePointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    final keyBindings = context.read<KeyBindingsProvider>();
    final action = keyBindings.getActionForMouseButtons(event.buttons);
    if (action == null) return;
    _handleHomeActionFromSource(action, InputSource.pointer);
  }

  /// 处理侧键事件流（浏览器前进/后退）。
  void _handleSideButtonStream(SideButtonEvent event) {
    if (!mounted) return;
    if (!event.isDown) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    final keyBindings = context.read<KeyBindingsProvider>();
    final action = keyBindings.getActionForMouseButtonType(event.button);
    if (action == null) return;
    _handleHomeActionFromSource(action, InputSource.sideButton);
  }

  /// 执行动作并处理不同输入源的去重逻辑。
  bool _handleHomeActionFromSource(BindableAction action, InputSource? source) {
    final projectProvider = context.read<ProjectProvider>();
    final canvasProvider = context.read<CanvasProvider>();
    final gate = _inputActionGate;

    switch (action) {
      case BindableAction.prevImage:
        if (source != null && !gate.shouldHandle(action, source)) return false;
        _navigateAndInfer(projectProvider, canvasProvider, previous: true);
        return true;
      case BindableAction.nextImage:
        if (source != null && !gate.shouldHandle(action, source)) return false;
        _navigateAndInfer(projectProvider, canvasProvider, previous: false);
        return true;
      case BindableAction.prevLabel:
        if (source != null && !gate.shouldHandle(action, source)) return false;
        final count = projectProvider.labels.length;
        if (count > 0) {
          final currentIndex = canvasProvider.selectedLabelIndex ?? 0;
          final newIndex = (currentIndex - 1 + count) % count;
          canvasProvider.selectLabel(newIndex);
        }
        return true;
      case BindableAction.nextLabel:
        if (source != null && !gate.shouldHandle(action, source)) return false;
        final count = projectProvider.labels.length;
        if (count > 0) {
          final currentIndex = canvasProvider.selectedLabelIndex ?? 0;
          final newIndex = (currentIndex + 1) % count;
          canvasProvider.selectLabel(newIndex);
        }
        return true;
      case BindableAction.deleteSelected:
        if (source != null && !gate.shouldHandle(action, source)) return false;
        _deleteSelectedLabel(projectProvider, canvasProvider);
        return true;
      case BindableAction.toggleMode:
        if (source != null && !gate.shouldHandle(action, source)) return false;
        canvasProvider.toggleLabelingMode();
        return true;
      case BindableAction.save:
        if (source != null && !gate.shouldHandle(action, source)) return false;
        projectProvider.saveLabels().then((ok) {
          if (!mounted) return;
          final l10n = AppLocalizations.of(context)!;
          if (ok) {
            ToastUtils.show(context, l10n.labelsSaved);
          } else if (projectProvider.error != null) {
            ToastUtils.showError(context, projectProvider.error!, l10n);
          } else {
            ToastUtils.showError(
              context,
              const AppError(AppErrorCode.ioOperationFailed),
              l10n,
            );
          }
        });
        return true;
      case BindableAction.toggleDarkEnhance:
        if (source != null && !gate.shouldHandle(action, source)) return false;
        canvasProvider.toggleDarkEnhancement();
        final l10n = AppLocalizations.of(context)!;
        ToastUtils.show(
          context,
          canvasProvider.enhanceDark
              ? l10n.darkEnhanceOnToast
              : l10n.darkEnhanceOffToast,
        );
        return true;
      case BindableAction.aiInference:
        if (source != null && !gate.shouldHandle(action, source)) return false;
        _runAiInference();
        return true;
      case BindableAction.toggleVisibility:
        if (source != null && !gate.shouldHandle(action, source)) return false;
        _toggleKeypointVisibility(projectProvider, canvasProvider);
        return true;
      case BindableAction.mouseCreate:
      case BindableAction.mouseDelete:
      case BindableAction.mouseMove:
      case BindableAction.zoomIn:
      case BindableAction.zoomOut:
      case BindableAction.nextClass:
      case BindableAction.undo:
      case BindableAction.redo:
      case BindableAction.cancelOperation:
      case BindableAction.cycleBinding:
        return false;
    }
  }

  /// 切换选中关键点的可见性
  void _toggleKeypointVisibility(
      ProjectProvider projectProvider, CanvasProvider canvasProvider) {
    final labelIndex = canvasProvider.selectedLabelIndex;
    final keypointIndex = canvasProvider.activeKeypointIndex;

    if (labelIndex == null || keypointIndex == null) return;
    if (labelIndex >= projectProvider.labels.length) return;

    final label = projectProvider.labels[labelIndex];
    if (keypointIndex >= label.points.length) return;

    final point = label.points[keypointIndex];
    // 循环切换：2(可见) -> 1(遮挡) -> 0(未标注) -> 2(可见)
    final newVisibility = (point.visibility + 2) % 3;

    final newPoints = List<LabelPoint>.from(label.points);
    newPoints[keypointIndex] = point.copyWith(visibility: newVisibility);

    projectProvider.updateLabel(labelIndex, label.copyWith(points: newPoints));

    final l10n = AppLocalizations.of(context)!;
    final visibilityNames = [
      l10n.visibilityNotLabeled,
      l10n.visibilityOccluded,
      l10n.visibilityVisible,
    ];
    final message = l10n.keypointVisibilityToast(
      keypointIndex + 1,
      visibilityNames[newVisibility],
    );
    ToastUtils.show(context, message);
  }

  /// 删除选中的标签
  void _deleteSelectedLabel(
      ProjectProvider projectProvider, CanvasProvider canvasProvider) {
    final selectedIndex = canvasProvider.selectedLabelIndex;
    if (selectedIndex != null) {
      projectProvider.removeLabel(selectedIndex);
      canvasProvider.selectLabel(null);
    }
  }

  /// 执行AI推理
  void _runAiInference() async {
    final projectProvider = context.read<ProjectProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;

    if (projectProvider.projectConfig == null) {
      ToastUtils.show(context, l10n.aiInferenceNoProject);
      return;
    }

    final aiConfig = projectProvider.projectConfig!.aiConfig;
    if (aiConfig.modelPath.isEmpty) {
      ToastUtils.show(context, l10n.aiInferenceNoModel);
      return;
    }

    ToastUtils.show(context, l10n.aiInferenceRunning);

    // 手动触发强制推理 (force: true)
    await projectProvider.autoLabelCurrent(
        useGpu: settingsProvider.useGpu, force: true);

    if (!mounted) return;

    if (projectProvider.error != null) {
      ToastUtils.showError(context, projectProvider.error!, l10n);
    } else {
      final count = projectProvider.labels.length;
      ToastUtils.show(context, l10n.aiInferenceComplete(count));
    }
  }

  /// 导航并根据配置自动推理
  void _navigateAndInfer(
      ProjectProvider projectProvider, CanvasProvider canvasProvider,
      {required bool previous}) async {
    final settingsProvider = context.read<SettingsProvider>();
    final moved = previous
        ? await projectProvider.previousImage(
            autoSave: settingsProvider.autoSaveOnNavigate,
          )
        : await projectProvider.nextImage(
            autoSave: settingsProvider.autoSaveOnNavigate,
          );
    if (!moved) {
      if (mounted && projectProvider.error != null) {
        ToastUtils.showError(
          context,
          projectProvider.error!,
          AppLocalizations.of(context)!,
        );
      }
      return;
    }
    canvasProvider.clearSelection();

    // 检查是否启用自动推理
    if (projectProvider.projectConfig != null &&
        projectProvider.projectConfig!.aiConfig.autoInferOnNext &&
        projectProvider.projectConfig!.aiConfig.modelPath.isNotEmpty) {
      if (!mounted) return;
      final currentImagePath = projectProvider.currentImagePath;
      if (currentImagePath != null &&
          projectProvider.isImageInferred(currentImagePath)) {
        return;
      }
      // 自动推理非强制 (force: false)，跳过已推理图片
      await projectProvider.autoLabelCurrent(
          useGpu: settingsProvider.useGpu, force: false);

      if (projectProvider.error == null &&
          projectProvider.labels.isNotEmpty &&
          mounted) {
        final l10n = AppLocalizations.of(context)!;
        ToastUtils.show(
          context,
          l10n.aiInferenceComplete(projectProvider.labels.length),
        );
      }
    }
  }
}
