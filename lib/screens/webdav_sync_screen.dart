import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_providers.dart';
import '../services/webdav_client.dart';
import '../services/webdav_sync_settings.dart';
import '../theme/app_colors.dart';
import '../widgets/ambient_glow.dart';
import '../widgets/app_pill_button.dart';
import '../widgets/page_header.dart';
import '../widgets/page_layout.dart';

/// 打开 WebDAV 云同步管理页（设置页与追剧页右上角设置图标共用）。
Future<void> openWebDavSync(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => const WebDavSyncScreen(),
    ),
  );
}

class WebDavSyncScreen extends ConsumerStatefulWidget {
  const WebDavSyncScreen({super.key});

  @override
  ConsumerState<WebDavSyncScreen> createState() => _WebDavSyncScreenState();
}

class _WebDavSyncScreenState extends ConsumerState<WebDavSyncScreen> {
  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _dirController = TextEditingController();

  bool _obscurePassword = true;
  bool _testing = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final WebDavSyncState syncState = await ref.read(
      webDavSyncProvider.future,
    );
    if (!mounted) {
      return;
    }
    final WebDavConfig config = syncState.settings.config;
    _serverController.text = config.serverUrl;
    // 展示归一化后的凭据：全角 ＠ 等会在页面上直接变成半角。
    _usernameController.text = config.authUsername;
    _passwordController.text = config.authPassword;
    _dirController.text = config.remoteDir;
    setState(() => _initialized = true);
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _dirController.dispose();
    super.dispose();
  }

  WebDavConfig get _draftConfig {
    return WebDavConfig(
      serverUrl: _serverController.text.trim(),
      username: normalizeWebDavCredential(_usernameController.text).trim(),
      password: normalizeWebDavCredential(_passwordController.text),
      remoteDir: _dirController.text.trim().isEmpty
          ? WebDavConfig.defaultRemoteDir
          : _dirController.text.trim(),
    );
  }

  /// 把输入框里的全角字符 / 零宽字符即时修正，用户能直接看到变化。
  void _normalizeFields() {
    final String username = normalizeWebDavCredential(_usernameController.text)
        .trim();
    final String password = normalizeWebDavCredential(_passwordController.text);
    if (username != _usernameController.text) {
      _usernameController.text = username;
    }
    if (password != _passwordController.text) {
      _passwordController.text = password;
    }
  }

  bool _validateDraft() {
    _normalizeFields();
    final Uri? uri = Uri.tryParse(_serverController.text.trim());
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https')) ||
        uri.host.isEmpty) {
      _toast('服务器地址需以 http:// 或 https:// 开头');
      return false;
    }
    if (_usernameController.text.trim().isEmpty) {
      _toast('请填写 WebDAV 账号');
      return false;
    }
    if (_passwordController.text.isEmpty) {
      _toast('请填写 WebDAV 应用密码');
      return false;
    }
    if (_draftConfig.hasUnsupportedCredential) {
      _toast('账号或密码含有无法识别的字符，请改用英文 / 半角输入');
      return false;
    }
    return true;
  }

  Future<bool> _saveConfig({bool autoSync = true, bool showToast = true}) async {
    if (!_validateDraft()) {
      return false;
    }
    await ref
        .read(webDavSyncProvider.notifier)
        .updateConfig(_draftConfig, autoSync: autoSync);
    if (showToast) {
      _toast('配置已保存');
    }
    return true;
  }

  Future<void> _testConnection() async {
    if (!_validateDraft() || _testing) {
      return;
    }
    setState(() => _testing = true);
    try {
      await ref
          .read(webDavSyncProvider.notifier)
          .testConnection(_draftConfig);
      _toast('连接成功');
    } on WebDavException catch (error) {
      _toast(error.message);
    } catch (error) {
      _toast('连接失败：$error');
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _syncNow() async {
    // 先用当前输入保存，避免改了地址却同步到旧服务器。
    final bool saved = await _saveConfig(autoSync: false, showToast: false);
    if (!saved || !mounted) {
      return;
    }
    final String message = await ref
        .read(webDavSyncProvider.notifier)
        .syncNow();
    if (mounted) {
      _toast(message);
    }
  }

  /// 切换同步策略；「覆盖云端」会丢云端独有记录，先二次确认。
  Future<void> _selectStrategy(SyncStrategy strategy) async {
    if (strategy == SyncStrategy.localOverwrite) {
      final bool confirmed =
          await showDialog<bool>(
            context: context,
            builder: (BuildContext dialogContext) => AlertDialog(
              title: const Text('以本地为准覆盖云端？'),
              content: const Text(
                '下次同步会用本机的收藏与观看记录替换云端文件，'
                '云端独有的记录会丢失，且无法撤销。',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('确认覆盖'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) {
        return;
      }
    }
    await ref.read(webDavSyncProvider.notifier).updateStrategy(strategy);
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 13)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final double horizontal = horizontalPagePadding(context);
    final AsyncValue<WebDavSyncState> asyncState = ref.watch(
      webDavSyncProvider,
    );
    final WebDavSyncState? syncState = asyncState.value;

    return Scaffold(
      backgroundColor: colors.page,
      body: AmbientGlow(
        child: Column(
          children: <Widget>[
            const PageHeader(title: 'WebDAV 云同步'),
            Expanded(
              child: !_initialized || syncState == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        8,
                        horizontal,
                        36,
                      ),
                      children: <Widget>[
                        _StatusCard(
                          state: syncState,
                          onSync: _syncNow,
                          onTest: _testConnection,
                          testing: _testing,
                        ),
                        const SizedBox(height: 20),
                        const _SectionCaption('服务器设置'),
                        _SectionCard(
                          children: <Widget>[
                            _FieldRow(
                              label: '服务器地址',
                              controller: _serverController,
                              hint: WebDavConfig.defaultServerUrl,
                              keyboardType: TextInputType.url,
                            ),
                            _FieldRow(
                              label: '账号',
                              controller: _usernameController,
                              hint: '坚果云登录邮箱',
                              keyboardType: TextInputType.emailAddress,
                            ),
                            _FieldRow(
                              label: '应用密码',
                              controller: _passwordController,
                              hint: '坚果云「安全选项」中生成的应用密码',
                              obscure: _obscurePassword,
                              suffix: IconButton(
                                tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 19,
                                  color: colors.textTertiary,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 36,
                                  height: 36,
                                ),
                              ),
                            ),
                            _FieldRow(
                              label: '远程文件夹',
                              controller: _dirController,
                              hint: WebDavConfig.defaultRemoteDir,
                              showDivider: false,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppPillButton(
                          label: '保存配置',
                          icon: Icons.save_outlined,
                          expand: true,
                          height: 44,
                          radius: 12,
                          tone: AppButtonTone.tonal,
                          onPressed: () => _saveConfig(),
                        ),
                        const SizedBox(height: 22),
                        const _SectionCaption('同步方式'),
                        _SectionCard(
                          children: <Widget>[
                            for (int i = 0; i < SyncMode.values.length; i++)
                              _ChoiceRow(
                                icon: _modeIcon(SyncMode.values[i]),
                                label: SyncMode.values[i].label,
                                description: SyncMode.values[i].description,
                                selected:
                                    syncState.settings.mode ==
                                    SyncMode.values[i],
                                showDivider: i < SyncMode.values.length - 1,
                                onTap: () => ref
                                    .read(webDavSyncProvider.notifier)
                                    .updateMode(SyncMode.values[i]),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        const _SectionCaption('同步策略'),
                        _SectionCard(
                          children: <Widget>[
                            for (int i = 0; i < SyncStrategy.values.length; i++)
                              _ChoiceRow(
                                icon: _strategyIcon(SyncStrategy.values[i]),
                                label: SyncStrategy.values[i].label,
                                description: SyncStrategy.values[i].description,
                                selected:
                                    syncState.settings.strategy ==
                                    SyncStrategy.values[i],
                                showDivider: i < SyncStrategy.values.length - 1,
                                onTap: () =>
                                    _selectStrategy(SyncStrategy.values[i]),
                              ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        const _SectionCaption('同步内容'),
                        const _ScopeCard(),
                        const SizedBox(height: 24),
                        const _HelpSection(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.state,
    required this.onSync,
    required this.onTest,
    required this.testing,
  });

  final WebDavSyncState state;
  final Future<void> Function() onSync;
  final Future<void> Function() onTest;
  final bool testing;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool configured = state.isConfigured;
    final bool syncing = state.syncing;

    final IconData icon;
    final Color iconColor;
    if (syncing) {
      icon = Icons.cloud_sync_rounded;
      iconColor = colors.brand;
    } else if (!configured) {
      icon = Icons.cloud_off_rounded;
      iconColor = colors.textTertiary;
    } else if (state.messageIsError) {
      icon = Icons.cloud_off_rounded;
      iconColor = colors.brand;
    } else if (state.settings.lastSyncAt != null) {
      icon = Icons.cloud_done_rounded;
      iconColor = colors.brand;
    } else {
      icon = Icons.cloud_queue_rounded;
      iconColor = colors.accentText;
    }

    final String title;
    if (syncing) {
      title = '正在同步…';
    } else if (!configured) {
      title = '尚未连接云盘';
    } else if (state.messageIsError) {
      title = '同步失败';
    } else if (state.settings.lastSyncAt != null) {
      title = '云同步已就绪';
    } else {
      title = '已配置，等待首次同步';
    }

    final String subtitle;
    if (state.message.isNotEmpty) {
      subtitle = state.message;
    } else if (state.settings.lastSyncAt != null) {
      subtitle = '上次同步：${_formatSyncTime(state.settings.lastSyncAt!)}';
    } else if (configured) {
      subtitle = '点「立即同步」把本机收藏与观看记录上传到云端';
    } else {
      subtitle = '填写下方服务器信息，坚果云账号可直接使用应用密码';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.hairline, width: 0.8),
        boxShadow: colors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.12),
                ),
                child: syncing
                    ? Padding(
                        padding: const EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: iconColor,
                        ),
                      )
                    : Icon(icon, size: 24, color: iconColor),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: state.messageIsError
                            ? colors.brand
                            : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: AppPillButton(
                  label: syncing ? '同步中…' : '立即同步',
                  icon: Icons.cloud_sync_rounded,
                  expand: true,
                  height: 42,
                  radius: 12,
                  onPressed: syncing ? null : onSync,
                ),
              ),
              const SizedBox(width: 10),
              AppPillButton(
                label: testing ? '测试中…' : '测试连接',
                tone: AppButtonTone.tonal,
                height: 42,
                radius: 12,
                horizontalPadding: 16,
                onPressed: testing ? null : onTest,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCaption extends StatelessWidget {
  const _SectionCaption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: context.colors.textTertiary,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

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

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.showDivider = true,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.2,
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: controller,
                      obscureText: obscure,
                      keyboardType: keyboardType,
                      autocorrect: false,
                      enableSuggestions: false,
                      cursorColor: colors.brand,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: hint,
                        hintStyle: TextStyle(
                          fontSize: 13.5,
                          height: 1.3,
                          color: colors.textTertiary.withValues(alpha: 0.75),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  ?suffix,
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 0.8,
            thickness: 0.8,
            indent: 16,
            endIndent: 16,
            color: colors.hairline,
          ),
      ],
    );
  }
}

IconData _modeIcon(SyncMode mode) {
  return switch (mode) {
    SyncMode.manual => Icons.touch_app_outlined,
    SyncMode.daily => Icons.schedule_rounded,
    SyncMode.onChange => Icons.bolt_outlined,
  };
}

IconData _strategyIcon(SyncStrategy strategy) {
  return switch (strategy) {
    SyncStrategy.merge => Icons.merge_type_rounded,
    SyncStrategy.localOverwrite => Icons.cloud_upload_outlined,
  };
}

/// 单选行：标题 + 一行说明 + 右侧勾选圈（同步方式 / 同步策略共用）。
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Column(
      children: <Widget>[
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 20,
                  color: selected ? colors.brand : colors.textSecondary,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 21,
                  color: selected ? colors.brand : colors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 0.8,
            thickness: 0.8,
            indent: 49,
            endIndent: 16,
            color: colors.hairline,
          ),
      ],
    );
  }
}

class _ScopeCard extends StatelessWidget {
  const _ScopeCard();

  static const List<(IconData, String, String)> _items =
      <(IconData, String, String)>[
        (Icons.star_outline_rounded, '收藏列表', '收藏 / 取消收藏双向同步'),
        (Icons.history_rounded, '观看记录', '看到第几集、播放到哪一秒'),
        (Icons.delete_outline_rounded, '删除记录', '删除墓碑传播到其他设备'),
      ];

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return _SectionCard(
      children: <Widget>[
        for (int i = 0; i < _items.length; i++)
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              i == _items.length - 1 ? 14 : 6,
            ),
            child: Row(
              children: <Widget>[
                Icon(_items[i].$1, size: 18, color: colors.textSecondary),
                const SizedBox(width: 12),
                Text(
                  _items[i].$2,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  _items[i].$3,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.3,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection();

  static const List<(String, String)> _notes = <(String, String)>[
    (
      '坚果云获取应用密码',
      '网页端右上角头像 →「账户信息」→「安全选项」→「添加应用」，生成专用密码。服务器地址保持 '
          'https://dav.jianguoyun.com/dav/，账号填登录邮箱（用半角 @，全角 ＠ 会自动转换），密码填应用密码（不是网页登录密码）。',
    ),
    (
      '通用 WebDAV',
      'Nextcloud、群晖、Alist 等服务商也可以使用：填写其 WebDAV 地址与账号即可，远程文件夹不存在时会自动创建。',
    ),
    (
      '安全与隐私',
      '账号与应用密码只保存在本机；云端只存放一个 watch-sync.json，内容为剧名、集数与播放进度，不含任何账号信息。',
    ),
    (
      '多设备合并',
      '同一部剧按「最近观看 / 收藏时间」自动取较新的一份；取消收藏与删除记录会以删除标记同步，不会被旧设备「复活」。'
          '选择「以本地为准覆盖云端」时不合并，直接用本机数据替换云端文件。',
    ),
    (
      '免费额度',
      '坚果云免费账号对上传流量与请求次数有限制。观看进度会随播放持续更新，频繁同步建议选择「每天自动同步」。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionCaption('说明'),
        for (final (String title, String body) note in _notes)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  note.$1,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  note.$2,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.55,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

String _formatSyncTime(DateTime time) {
  final DateTime now = DateTime.now();
  final Duration diff = now.difference(time);
  if (diff.inSeconds < 60) {
    return '刚刚';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} 分钟前';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} 小时前';
  }
  String two(int value) => value.toString().padLeft(2, '0');
  if (diff.inDays < 7) {
    return '${diff.inDays} 天前 · ${two(time.hour)}:${two(time.minute)}';
  }
  return '${time.year}/${two(time.month)}/${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}
