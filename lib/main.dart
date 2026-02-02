import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'app/theme.dart';
import 'providers/project_provider.dart';
import 'providers/canvas_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/keybindings_provider.dart';
import 'providers/project_list_provider.dart';
import 'pages/project_list_page.dart';
import 'services/app/app_services.dart';

/// 应用入口。
///
/// 在启动前确保 Flutter 绑定初始化，以便后续插件和平台通道可用。
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LabelLoadApp());
}

/// LabelLoad 应用根组件。
///
/// 统一装配依赖、初始化所有 Provider 并配置 MaterialApp。
/// 可通过 [servicesBuilder] 注入替代实现，便于测试或扩展。
class LabelLoadApp extends StatelessWidget {
  const LabelLoadApp({
    super.key,
    this.servicesBuilder = AppServices.new,
  });

  /// 构建服务聚合的工厂，默认创建 [AppServices]。
  ///
  /// 在测试中可注入 fake 实现，避免访问真实文件系统或推理引擎。
  final AppServices Function() servicesBuilder;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => servicesBuilder()),
        ChangeNotifierProvider(
          create: (context) => ProjectListProvider(
            repository: context.read<AppServices>().projectListRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) {
            final services = context.read<AppServices>();
            return ProjectProvider(
              repository: services.projectRepository,
              inferenceController: services.projectInferenceController,
            );
          },
        ),
        ChangeNotifierProvider(create: (_) => CanvasProvider()),
        ChangeNotifierProvider(
          create: (context) =>
              ThemeProvider(store: context.read<AppServices>().themeStore),
        ),
        ChangeNotifierProvider(
          create: (context) => SettingsProvider(
            store: context.read<AppServices>().settingsStore,
            gpuDetector: context.read<AppServices>().gpuDetector,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => KeyBindingsProvider(
            store: context.read<AppServices>().keyBindingsStore,
            keyboardStateReader:
                context.read<AppServices>().keyboardStateReader,
          ),
        ),
      ],
      child: Consumer2<ProjectProvider, ThemeProvider>(
        builder: (context, projectProvider, themeProvider, child) {
          return MaterialApp(
            title: 'LabelLoad',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: Locale(projectProvider.config.locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const _SplashWrapper(),
          );
        },
      ),
    );
  }
}

/// 启动画面包装器
///
/// 显示加载动画，等待所有 Provider 初始化完成后跳转到主页面。
class _SplashWrapper extends StatefulWidget {
  const _SplashWrapper();

  @override
  State<_SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<_SplashWrapper> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// 初始化应用
  Future<void> _initializeApp() async {
    // 预初始化 SharedPreferences，避免首次读取时阻塞界面渲染。
    await SharedPreferences.getInstance();

    if (!mounted) return;
    final themeProvider = context.read<ThemeProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final keyBindingsProvider = context.read<KeyBindingsProvider>();

    // 等待所有 Provider 初始化完成
    while (!themeProvider.isInitialized ||
        !settingsProvider.isInitialized ||
        !keyBindingsProvider.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }

    // 延迟一小段时间使过渡更平滑，避免闪烁。
    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      setState(() {
        _isReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) {
      return const ProjectListPage();
    }
    return _buildSplashScreen();
  }

  /// 构建启动画面
  ///
  /// 统一展示品牌元素与加载提示，并保持与主题色一致。
  Widget _buildSplashScreen() {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 应用图标
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.label_outline,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            // 应用名称
            Text(
              'LabelLoad',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.splashSubtitle,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.getTextMuted(context),
              ),
            ),
            const SizedBox(height: 48),
            // 加载指示器
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.splashLoading,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.getTextMuted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
