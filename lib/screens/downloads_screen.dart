import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';
import '../widgets/page_layout.dart';
import '../widgets/underline_tabs.dart';
import '../widgets/ambient_glow.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key, required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  int _tabIndex = 0;

  void _goBrowse() {
    widget.onBrowse();
    Navigator.of(context).maybePop();
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
            const PageHeader(title: '我的下载'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontal),
              child: UnderlineTabs(
                labels: const <String>['已下载', '下载中'],
                selectedIndex: _tabIndex,
                onChanged: (int index) => setState(() => _tabIndex = index),
              ),
            ),
            Expanded(
              child: SafeArea(
                top: false,
                child: Center(
                  child: SingleChildScrollView(
                    child: _tabIndex == 0
                        ? EmptyState(
                            icon: Icons.file_download_outlined,
                            accent: const Color(0xFF7E9BE0),
                            title: '暂无下载内容',
                            message: '去看看喜欢的短剧吧~',
                            actionLabel: '去逛逛',
                            onAction: _goBrowse,
                          )
                        : EmptyState(
                            icon: Icons.downloading_rounded,
                            accent: const Color(0xFF7E9BE0),
                            title: '暂无正在下载的任务',
                            message: '缓存后即可离线观看，随时随地开看',
                            actionLabel: '去逛逛',
                            onAction: _goBrowse,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
