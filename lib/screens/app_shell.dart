import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/sync_providers.dart';
import '../services/update_prompt.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 'category_screen.dart';
import 'following_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'watch_feed_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const int _followingIndex = 3;

  /// 宽窗断点：达到即用左侧导航栏（桌面），否则底部导航（移动端）。
  /// 手机竖屏宽度（含平板 1/2 分屏）远低于该值，行为不变。
  static const double _wideLayoutBreakpoint = 720;

  int _index = 0;
  FollowingTab _followingTab = FollowingTab.continueWatching;

  @override
  void initState() {
    super.initState();
    // 启动默认检查更新：静默模式（失败/已是最新不提示，仅发现新版弹窗）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startupUpdateCheck();
      _startupAutoSync();
    });
  }

  /// 启动时按同步方式补一次自动同步（provider 就绪后执行）。
  Future<void> _startupAutoSync() async {
    try {
      final WebDavSyncController controller = ref.read(
        webDavSyncProvider.notifier,
      );
      await ref.read(webDavSyncProvider.future);
      if (mounted) {
        controller.checkAutoSync();
      }
    } catch (_) {
      // 同步初始化失败不影响主流程。
    }
  }

  Future<void> _startupUpdateCheck() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (!mounted) {
        return;
      }
      await UpdatePrompt.check(context, currentVersion: info.version, silent: true);
    } catch (_) {
      // 插件未注册（测试环境）等情况：静默跳过。
    }
  }

  void _selectTab(int index) {
    if (index == _index) {
      return;
    }
    setState(() => _index = index);
  }

  void _openFollowing(FollowingTab tab) {
    setState(() {
      _index = _followingIndex;
      _followingTab = tab;
    });
  }

  void _openCategory() {
    setState(() => _index = 1);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool isDark = context.isDark;
    // 保活 WebDAV 同步控制器：应用启动即挂上变更监听与每日检查，
    // 不需要用户先打开同步设置页。
    ref.watch(webDavSyncProvider);
    final SystemUiOverlayStyle overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: colors.navBar,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= _wideLayoutBreakpoint;
          final Widget content = IndexedStack(
            index: _index,
            children: <Widget>[
              const HomeScreen(),
              const CategoryScreen(),
              const WatchFeedScreen(),
              FollowingScreen(
                selectedTab: _followingTab,
                onTabChanged: (FollowingTab tab) =>
                    setState(() => _followingTab = tab),
              ),
              ProfileScreen(
                onOpenFollowing: _openFollowing,
                onOpenCategory: _openCategory,
              ),
            ],
          );

          return Scaffold(
            backgroundColor: colors.page,
            body: wide
                ? Row(
                    children: <Widget>[
                      AppSideNav(index: _index, onChanged: _selectTab),
                      Expanded(child: content),
                    ],
                  )
                : content,
            bottomNavigationBar: wide
                ? null
                : AppBottomNav(index: _index, onChanged: _selectTab),
          );
        },
      ),
    );
  }
}
