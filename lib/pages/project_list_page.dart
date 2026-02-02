import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'project_settings_page.dart';
import 'home_page.dart';
import '../providers/project_list_provider.dart';
import '../providers/project_provider.dart';
import '../models/project_config.dart';
import '../app/theme.dart';
import '../services/projects/project_cover_finder.dart';
import '../services/image/image_preview_provider.dart';
import '../services/app/app_services.dart';
import '../widgets/dialogs/gadgets_dialog.dart';
import '../widgets/dialogs/global_settings_dialog.dart';

/// 项目列表页面
///
/// 显示所有项目卡片，支持打开、编辑、删除项目。
class ProjectListPage extends StatefulWidget {
  const ProjectListPage({
    super.key,
    this.coverFinder,
    this.imagePreviewProvider,
  });

  /// 注入封面查找器，便于测试或替换默认实现。
  final ProjectCoverFinder? coverFinder;

  /// 注入封面图片提供器，便于测试或替换默认实现。
  final ImagePreviewProvider? imagePreviewProvider;

  @override
  State<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends State<ProjectListPage> {
  late final ProjectCoverFinder _coverFinder;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final services = context.read<AppServices>();
    _coverFinder = widget.coverFinder ?? services.projectCoverFinder;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ProjectListProvider>().loadProjects();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 打开项目
  Future<void> _openProject(ProjectConfig config) async {
    final projectProvider = context.read<ProjectProvider>();
    final projectListProvider = context.read<ProjectListProvider>();

    await projectProvider.loadProject(config);

    // 检查是否有AI自动填充的标签定义需要保存
    final pendingUpdate = projectProvider.pendingConfigUpdate;
    if (pendingUpdate != null) {
      await projectListProvider.updateProject(pendingUpdate);
      config = pendingUpdate;
    }

    if (mounted) {
      final services = context.read<AppServices>();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HomePage(
            sideButtonService: services.sideButtonService,
            inputActionGate: services.inputActionGate,
            keyboardStateReader: services.keyboardStateReader,
          ),
        ),
      );
    }
  }

  /// 编辑项目配置
  void _editProject(ProjectConfig config) {
    final services = context.read<AppServices>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectSettingsPage(
          project: config,
          batchInferenceService: services.batchInferenceService,
        ),
      ),
    );
  }

  /// 删除项目
  Future<void> _deleteProject(ProjectConfig config) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProjectConfirmTitle),
        content: Text(l10n.deleteProjectConfirmMsg(config.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<ProjectListProvider>().removeProject(config.id);
    }
  }

  /// 查找封面图片
  Future<String?> _findCoverImagePath(String dirPath) async {
    return _coverFinder.findFirstImagePath(dirPath);
  }

  @override
  Widget build(BuildContext context) {
    final listProvider = context.watch<ProjectListProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.label, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(l10n.projectListTitle,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_customize_outlined),
            tooltip: l10n.toolboxTooltip,
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const GadgetsDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.globalSettingsTooltip,
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const GlobalSettingsDialog(),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final services = context.read<AppServices>();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProjectSettingsPage(
                batchInferenceService: services.batchInferenceService,
              ),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: _buildBody(listProvider, l10n),
    );
  }

  /// 构建页面主体
  Widget _buildBody(ProjectListProvider listProvider, AppLocalizations l10n) {
    if (listProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (listProvider.error != null) {
      return Center(child: Text(listProvider.error!.message(l10n)));
    }

    if (listProvider.projects.isEmpty) {
      return Center(child: Text(l10n.noProjects));
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 20,
            children: listProvider.projects
                .map((project) => _buildProjectCard(project, l10n))
                .toList(),
          ),
        ),
      ),
    );
  }

  /// 构建项目卡片
  Widget _buildProjectCard(ProjectConfig project, AppLocalizations l10n) {
    return SizedBox(
      width: 300,
      height: 360,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 封面图片
                Expanded(
                  flex: 5,
                  child: Container(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: FutureBuilder<String?>(
                      future: _findCoverImagePath(project.imagePath),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null) {
                          final services = context.read<AppServices>();
                          final provider = widget.imagePreviewProvider ??
                              services.imagePreviewProvider;
                          return Image(
                            image: provider.create(snapshot.data!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image,
                              size: 40,
                              color: Colors.grey,
                            ),
                          );
                        }
                        return const Icon(Icons.image_not_supported_outlined,
                            size: 48, color: Colors.grey);
                      },
                    ),
                  ),
                ),

                // 项目信息
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1),
                        const SizedBox(height: 4),
                        Expanded(
                            child: Text(project.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.label_outline,
                                size: 14,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color),
                            const SizedBox(width: 4),
                            Text(
                                l10n.labelsCount(
                                    project.labelDefinitions.length),
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 点击区域
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openProject(project),
                ),
              ),
            ),

            // 操作按钮
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: Icons.settings,
                    onTap: () => _editProject(project),
                  ),
                  const SizedBox(width: 4),
                  _buildActionButton(
                    icon: Icons.delete,
                    color: Colors.red.shade400,
                    onTap: () => _deleteProject(project),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
