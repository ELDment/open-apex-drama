import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_state/profile.dart';
import '../app_state/sync_settings.dart';
import '../app_state/project_info.dart';
import '../providers/watch_providers.dart';
import '../services/external_link.dart';
import '../services/update_prompt.dart';
import '../theme/app_colors.dart';
import '../widgets/ambient_glow.dart';
import '../widgets/app_pill_button.dart';
import '../widgets/page_layout.dart';
import '../widgets/setting_tile.dart';
import 'downloads_screen.dart';
import 'following_screen.dart';
import 'membership_screen.dart';
import 'placeholder_screen.dart';
import 'settings_screen.dart';

/// 会员体系暂未上线：先隐藏「开通会员」入口。
/// 会员页、banner 与相关代码全部保留，上线时把开关改回 true 即可恢复。
const bool _showMembershipEntry = false;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onOpenFollowing,
    required this.onOpenCategory,
  });

  final ValueChanged<FollowingTab> onOpenFollowing;
  final VoidCallback onOpenCategory;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _version = '';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  /// 「我的」页快捷检查更新（与设置页共用同一弹窗与提示逻辑）。
  Future<void> _checkUpdate() async {
    if (_checkingUpdate || _version.isEmpty) {
      return;
    }
    setState(() => _checkingUpdate = true);
    await UpdatePrompt.check(context, currentVersion: _version);
    if (mounted) {
      setState(() => _checkingUpdate = false);
    }
  }

  /// 真实版本号；测试 / 插件未注册环境静默降级为空（不展示版本）。
  Future<void> _loadVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = info.version);
      }
    } catch (_) {
      // MissingPluginException：测试环境，保持空值。
    }
  }

  Future<void> _editProfile() async {
    final TextEditingController controller = TextEditingController(
      text: profileNotifier.value.nickname,
    );
    final String? nickname = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final AppColors colors = sheetContext.colors;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.hairline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '编辑昵称',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 16,
                  cursorColor: colors.brand,
                  style: TextStyle(
                    fontSize: 15,
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '给自己起个名字吧',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: colors.textTertiary,
                    ),
                    filled: true,
                    fillColor: colors.page,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.hairline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.hairline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.brand),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AppPillButton(
                  label: '保存',
                  expand: true,
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(controller.text),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (nickname == null) {
      return;
    }
    await rememberNickname(nickname);
    if (mounted) {
      setState(() {}); // 头像首字与昵称同步刷新
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final double horizontal = horizontalPagePadding(context);
    final UserProfile profile = profileNotifier.value;

    // 「我的」页统计走真实本地数据：追剧 = 继续观看条数，
    // 收藏 / 历史 = 对应列表条数，与追剧页天然联动。
    final int followingCount = ref.watch(continueWatchingProvider).length;
    final int favoriteCount =
        ref.watch(favoritesProvider).value?.length ?? 0;
    final int historyCount = ref.watch(historyProvider).value?.length ?? 0;

    return AmbientGlow(
      bottomGlow: true,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 28),
          children: <Widget>[
            // 桌面宽窗不再左右分栏：会员入口隐藏后左栏只剩头像与统计，
            // 分栏会显得很空。统一居中单列并限制最大宽度，宽屏自然左右留白。
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: <Widget>[
                    _ProfileHeader(
                      nickname: profile.nickname,
                      userId: profile.userId,
                      avatarChar: profile.avatarChar,
                      onTap: _editProfile,
                    ),
                    const SizedBox(height: 20),
                    _StatsRow(
                      followingCount: followingCount,
                      favoriteCount: favoriteCount,
                      historyCount: historyCount,
                      onOpenFollowing: widget.onOpenFollowing,
                    ),
                    if (_showMembershipEntry) ...<Widget>[
                      const SizedBox(height: 20),
                      _MembershipBanner(
                        onTap: () => openMembership(context),
                      ),
                      const SizedBox(height: 16),
                    ] else
                      const SizedBox(height: 20),
                    _MenuPanel(
                      onOpenFollowing: widget.onOpenFollowing,
                      onOpenCategory: widget.onOpenCategory,
                    ),
                    const SizedBox(height: 24),
                    AppPillButton(
                      icon: Icons.system_update_rounded,
                      label: _checkingUpdate ? '正在检查更新…' : '检查更新',
                      expand: true,
                      onPressed: _checkingUpdate ? null : _checkUpdate,
                    ),
                    const SizedBox(height: 10),
                    AppPillButton(
                      icon: Icons.star_rounded,
                      label: '去 GitHub 给 $projectRepoName 点 Star',
                      tone: AppButtonTone.gold,
                      expand: true,
                      onPressed: () => openInBrowser(context, projectRepoUrl),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        _version.isEmpty ? 'ApexDrama' : 'ApexDrama v$_version',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.2,
                          color: colors.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.nickname,
    required this.userId,
    required this.avatarChar,
    required this.onTap,
  });

  final String nickname;
  final String userId;
  final String avatarChar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFFF1DFFF), Color(0xFFC7A9F2)],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: colors.softShadow,
            ),
            child: Text(
              avatarChar,
              style: const TextStyle(
                fontSize: 25,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ID: $userId',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.2,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: colors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.followingCount,
    required this.favoriteCount,
    required this.historyCount,
    required this.onOpenFollowing,
  });

  final int followingCount;
  final int favoriteCount;
  final int historyCount;
  final ValueChanged<FollowingTab> onOpenFollowing;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final List<FollowingTab> targets = <FollowingTab>[
      FollowingTab.continueWatching,
      FollowingTab.favorites,
      FollowingTab.history,
    ];
    final List<String> values = <String>[
      '$followingCount',
      '$favoriteCount',
      '$historyCount',
    ];
    const List<String> labels = <String>['追剧', '收藏', '历史'];

    return Row(
      children: <Widget>[
        for (int i = 0; i < labels.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => onOpenFollowing(targets[i]),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: <Widget>[
                    Text(
                      values[i],
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MembershipBanner extends StatelessWidget {
  const _MembershipBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: AppTokens.gradientChampagne,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: AppTokens.gold.withValues(alpha: 0.42),
            width: 0.8,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
            child: Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3A2716).withValues(alpha: 0.92),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 19,
                    color: Color(0xFFF6DCA6),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '尊享会员',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2F200F),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '解锁更多精彩内容',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          height: 1.2,
                          color: Color(0xFF5C4326),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: const Color(0xFF3A2716),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      child: Text(
                        '开通会员',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF6DCA6),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({
    required this.onOpenFollowing,
    required this.onOpenCategory,
  });

  final ValueChanged<FollowingTab> onOpenFollowing;
  final VoidCallback onOpenCategory;

  void _openDownloads(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => DownloadsScreen(
          onBrowse: () {
            Navigator.of(context).maybePop();
            onOpenCategory();
          },
        ),
      ),
    );
  }

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
      child: Column(
        children: <Widget>[
          SettingTile(
            icon: Icons.history_rounded,
            title: '观看历史',
            iconSize: 21,
            onTap: () => onOpenFollowing(FollowingTab.history),
          ),
          SettingTile(
            icon: Icons.star_outline_rounded,
            title: '我的收藏',
            iconSize: 21,
            onTap: () => onOpenFollowing(FollowingTab.favorites),
          ),
          SettingTile(
            icon: Icons.download_for_offline_outlined,
            title: '离线缓存',
            iconSize: 21,
            onTap: () => _openDownloads(context),
          ),
          SettingTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: '意见反馈',
            iconSize: 20,
            onTap: () => openPlaceholder(
              context,
              title: '意见反馈',
              icon: Icons.chat_bubble_outline_rounded,
              message: '反馈入口将在后续版本开放',
            ),
          ),
          SettingTile(
            icon: Icons.settings_outlined,
            title: '设置',
            showDivider: false,
            iconSize: 21,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext _) => const SettingsScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
