import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_state/appearance.dart';
import '../app_state/profile.dart';
import '../providers/sync_providers.dart';
import '../services/update_prompt.dart';
import '../services/webdav_sync_settings.dart';
import '../theme/app_colors.dart';
import '../widgets/ambient_glow.dart';
import '../widgets/page_header.dart';
import '../widgets/page_layout.dart';
import '../widgets/setting_tile.dart';
import 'about_screen.dart';
import 'placeholder_screen.dart';
import 'sdk_debug_screen.dart';
import 'webdav_sync_screen.dart';

/// 隐藏调试入口：仅当昵称精确等于该值时展示「SDK 调试」。
const String _debugNickname = '上玄';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _followSystem = true;
  bool _nightMode = false;
  bool _checkingUpdate = false;
  String _currentVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
    switch (appearanceMode.value) {
      case ThemeMode.system:
        _followSystem = true;
      case ThemeMode.dark:
        _followSystem = false;
        _nightMode = true;
      case ThemeMode.light:
        _followSystem = false;
        _nightMode = false;
    }
  }

  Future<void> _loadVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _currentVersion = info.version);
    }
  }

  /// 检查更新：GitHub Release latest 对比当前版本，有新版弹窗引导浏览器下载。
  Future<void> _checkUpdate() async {
    if (_checkingUpdate) {
      return;
    }
    setState(() => _checkingUpdate = true);
    await UpdatePrompt.check(context, currentVersion: _currentVersion);
    if (mounted) {
      setState(() => _checkingUpdate = false);
    }
  }

  void _applyAppearance() {
    saveAppearance(
      _followSystem
          ? ThemeMode.system
          : (_nightMode ? ThemeMode.dark : ThemeMode.light),
    );
  }

  void _open(BuildContext context, String title, IconData icon) {
    openPlaceholder(
      context,
      title: title,
      icon: icon,
      message: '「$title」将在后续版本开放',
    );
  }

  /// 设置页右侧状态：未配置 / 当前同步方式简称。
  String? _syncSummary(WebDavSyncState? state) {
    if (state == null) {
      return null;
    }
    if (!state.isConfigured) {
      return '未配置';
    }
    return switch (state.settings.mode) {
      SyncMode.manual => '手动',
      SyncMode.daily => '每天',
      SyncMode.onChange => '自动',
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final double horizontal = horizontalPagePadding(context);
    final WebDavSyncState? syncState = ref.watch(webDavSyncProvider).value;

    return Scaffold(
      backgroundColor: colors.page,
      body: AmbientGlow(
        child: Column(
          children: <Widget>[
            const PageHeader(title: '设置'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 28),
                children: <Widget>[
                  _SettingsGroup(
                    children: <Widget>[
                      SettingTile(
                        icon: Icons.brightness_auto_outlined,
                        title: '跟随系统',
                        trailing: Switch(
                          value: _followSystem,
                          onChanged: (bool value) {
                            setState(() => _followSystem = value);
                            _applyAppearance();
                          },
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      SettingTile(
                        icon: Icons.dark_mode_outlined,
                        title: '夜间模式',
                        showDivider: false,
                        trailing: Switch(
                          // 跟随系统时展示当前生效状态但不可操作
                          value: _followSystem
                              ? MediaQuery.platformBrightnessOf(context) ==
                                    Brightness.dark
                              : _nightMode,
                          onChanged: _followSystem
                              ? null
                              : (bool value) {
                                  setState(() => _nightMode = value);
                                  _applyAppearance();
                                },
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SettingsGroup(
                    children: <Widget>[
                      SettingTile(
                        icon: Icons.cloud_sync_outlined,
                        title: 'WebDAV 云同步',
                        value: _syncSummary(syncState),
                        showDivider: false,
                        onTap: () => openWebDavSync(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SettingsGroup(
                    children: <Widget>[
                      SettingTile(
                        icon: Icons.person_outline_rounded,
                        title: '账号与安全',
                        onTap: () => _open(
                          context,
                          '账号与安全',
                          Icons.person_outline_rounded,
                        ),
                      ),
                      SettingTile(
                        icon: Icons.play_circle_outline_rounded,
                        title: '播放设置',
                        onTap: () => _open(
                          context,
                          '播放设置',
                          Icons.play_circle_outline_rounded,
                        ),
                      ),
                      SettingTile(
                        icon: Icons.hd_outlined,
                        title: '清晰度选择',
                        value: '1080P',
                        onTap: () => _open(context, '清晰度选择', Icons.hd_outlined),
                      ),
                      SettingTile(
                        icon: Icons.notifications_none_rounded,
                        title: '消息通知',
                        trailing: Switch(
                          value: _notificationsEnabled,
                          onChanged: (bool value) =>
                              setState(() => _notificationsEnabled = value),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      SettingTile(
                        icon: Icons.system_update_rounded,
                        title: '检查更新',
                        value: _checkingUpdate
                            ? '检查中…'
                            : (_currentVersion.isEmpty
                                  ? null
                                  : 'v$_currentVersion'),
                        onTap: _checkingUpdate ? null : _checkUpdate,
                      ),
                      SettingTile(
                        icon: Icons.lock_outline_rounded,
                        title: '隐私设置',
                        onTap: () =>
                            _open(context, '隐私设置', Icons.lock_outline_rounded),
                      ),
                      ValueListenableBuilder<UserProfile>(
                        valueListenable: profileNotifier,
                        builder: (BuildContext context, UserProfile profile, _) {
                          // 默认隐藏调试入口，仅「上玄」可见。
                          if (profile.nickname.trim() != _debugNickname) {
                            return const SizedBox.shrink();
                          }
                          return SettingTile(
                            icon: Icons.bug_report_outlined,
                            title: 'SDK 调试',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) =>
                                    const SdkDebugScreen(),
                              ),
                            ),
                          );
                        },
                      ),
                      SettingTile(
                        icon: Icons.info_outline_rounded,
                        title: '关于我们',
                        value: _currentVersion.isEmpty
                            ? null
                            : 'v$_currentVersion',
                        showDivider: false,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const AboutScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _LogoutButton(
                    onTap: () => openPlaceholder(
                      context,
                      title: '退出登录',
                      icon: Icons.logout_rounded,
                      message: '当前为界面演示，未接入账号体系',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      'ApexDrama · 让好剧触手可及',
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.3,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.hairline, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: colors.hairline, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Center(
            child: Text(
              '退出登录',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
