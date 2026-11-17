import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../app_state/project_info.dart';
import '../services/external_link.dart';
import '../theme/app_colors.dart';
import '../widgets/ambient_glow.dart';
import '../widgets/app_pill_button.dart';
import '../widgets/page_header.dart';
import '../widgets/page_layout.dart';
import '../widgets/setting_tile.dart';

/// 「关于我们」：项目信息、开源仓库地址、作者与 Star 入口。
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
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

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final double horizontal = horizontalPagePadding(context);

    return Scaffold(
      backgroundColor: colors.page,
      body: AmbientGlow(
        child: Column(
          children: <Widget>[
            const PageHeader(title: '关于我们'),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 28),
                children: <Widget>[
                  const SizedBox(height: 18),
                  _BrandCard(version: _version),
                  const SizedBox(height: 20),
                  _InfoGroup(
                    children: <Widget>[
                      SettingTile(
                        icon: Icons.code_rounded,
                        title: '开源仓库',
                        value: projectRepoShort,
                        iconSize: 20,
                        onTap: () => openInBrowser(context, projectRepoUrl),
                      ),
                      SettingTile(
                        icon: Icons.person_outline_rounded,
                        title: '作者',
                        value: projectAuthorName,
                        iconSize: 20,
                        onTap: () =>
                            openInBrowser(context, projectAuthorUrl),
                      ),
                      SettingTile(
                        icon: Icons.star_outline_rounded,
                        title: '给 open-apex-drama 点 Star',
                        value: 'GitHub',
                        showDivider: false,
                        iconSize: 20,
                        onTap: () => openInBrowser(context, projectRepoUrl),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  AppPillButton(
                    icon: Icons.star_rounded,
                    label: '去 GitHub 点个 Star，支持持续更新',
                    tone: AppButtonTone.gold,
                    expand: true,
                    onPressed: () => openInBrowser(context, projectRepoUrl),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'ApexDrama 是一款基于开源 SDK 的第三方短剧客户端：'
                    '非官方、免登录，追剧 / 收藏 / 历史与个人资料等数据'
                    '全部保存在你的设备上，不依赖任何后端账号体系。'
                    '项目在 GitHub 开源，喜欢的话去给 '
                    '$projectRepoName 点个 Star 吧！',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.7,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '免责声明：本项目基于非官方接口，仅供学习研究，'
                    '禁止商业用途与大规模采集。接口与内容版权归原平台'
                    '所有，使用风险自负。',
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.6,
                      color: colors.textTertiary,
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

/// 头部品牌卡：logo + 名称 + 口号 + 版本号。
class _BrandCard extends StatelessWidget {
  const _BrandCard({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Column(
      children: <Widget>[
        Container(
          width: 88,
          height: 88,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.hairline, width: 0.8),
            boxShadow: colors.softShadow,
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'ApexDrama',
          style: TextStyle(
            fontSize: 21,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          projectSlogan,
          style: TextStyle(
            fontSize: 12,
            height: 1.2,
            color: colors.textSecondary,
          ),
        ),
        if (version.isNotEmpty) ...<Widget>[
          const SizedBox(height: 5),
          Text(
            'v$version',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.2,
              color: colors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoGroup extends StatelessWidget {
  const _InfoGroup({required this.children});

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
