import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../data/remote/openhongguo_service.dart';
import '../data/repository/repositories.dart';
import '../models/catalog.dart';
import '../models/drama.dart';
import '../models/playback.dart';
import '../player/video_output.dart';
import '../providers/data_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/page_header.dart';
import '../widgets/page_layout.dart';

/// SDK 链路 POC 页：发现/搜索 → 分集 → 播放解析 → media_kit 试播。
/// 面向开发调试，界面从简，日志驱动。
class SdkDebugScreen extends ConsumerStatefulWidget {
  const SdkDebugScreen({super.key});

  @override
  ConsumerState<SdkDebugScreen> createState() => _SdkDebugScreenState();
}

class _SdkDebugScreenState extends ConsumerState<SdkDebugScreen> {
  final TextEditingController _queryController = TextEditingController();

  Player? _player;
  VideoController? _videoController;

  List<Drama> _series = <Drama>[];
  Drama? _selectedSeries;
  List<EpisodeInfo> _episodes = <EpisodeInfo>[];
  EpisodeInfo? _selectedEpisode;
  PlaybackBundle? _bundle;
  StreamInfo? _selectedStream;
  bool _busy = false;
  final List<String> _logs = <String>[];

  @override
  void dispose() {
    _queryController.dispose();
    _unmountPlayer();
    super.dispose();
  }

  void _log(String line) {
    debugPrint('[sdk-poc] $line');
    setState(() {
      _logs.insert(0, line);
      if (_logs.length > 120) {
        _logs.removeLast();
      }
    });
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    _log('$label …');
    final Stopwatch watch = Stopwatch()..start();
    try {
      await action();
      _log('$label ✓ ${watch.elapsedMilliseconds}ms');
    } on ApiException catch (error) {
      final int wait = error.retryAfterMs ?? 0;
      _log('$label ✗ [${error.code}] ${error.message}'
          '${wait > 0 ? ' (建议等待${wait}ms)' : ''}');
    } catch (error) {
      _log('$label ✗ $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  // ---------- 数据动作（内部无互斥包装，供单步按钮与全链路复用） ----------

  Future<void> _doDiscover({String channel = '推荐'}) async {
    final DramaPage page = await ref
        .read(catalogRepositoryProvider)
        .discoverFeed(channel);
    final List<Drama> items = page.items;
    _series = items;
    _selectedSeries = items.isNotEmpty ? items.first : null;
    _selectedEpisode = null;
    _bundle = null;
    _selectedStream = null;
    _log('共 ${items.length} 部，选中「${_selectedSeries?.title}」');
  }

  Future<void> _doSearch(String query) async {
    final SearchPage page =
        await ref.read(catalogRepositoryProvider).searchPage(query);
    final List<Drama> items = page.items;
    _series = items;
    _selectedSeries = items.isNotEmpty ? items.first : null;
    _selectedEpisode = null;
    _bundle = null;
    _selectedStream = null;
    _log('共 ${items.length} 部，选中「${_selectedSeries?.title}」');
  }

  Future<void> _doEpisodes() async {
    final Drama? series = _selectedSeries;
    if (series == null) {
      throw StateError('先选中一部剧');
    }
    _episodes = await ref.read(playbackRepositoryProvider).episodes(series.id);
    _selectedEpisode = _episodes.isNotEmpty ? _episodes.first : null;
    _log('《${series.title}》共 ${_episodes.length} 集，选中第 ${_selectedEpisode?.number} 集');
  }

  Future<void> _doResolve() async {
    final EpisodeInfo? episode = _selectedEpisode;
    if (episode == null) {
      throw StateError('先选中一集');
    }
    final PlaybackBundle bundle =
        await ref.read(playbackRepositoryProvider).resolve(episode.id);
    _bundle = bundle;
    _selectedStream = bundle.preferred;
    _log('流 ${bundle.streams.length} 个，'
        'key=${bundle.hasKey ? '${bundle.contentKeyHex.substring(0, 8)}…' : '无'}，'
        '时长 ${bundle.durationSeconds}s');
    if (bundle.hasKey) {
      _log('FULL-KEY ${bundle.contentKeyHex}');
    }
    for (final StreamInfo s in bundle.streams) {
      _log('  ${s.label}');
      _log('FULL-URL ${s.url}');
    }
  }

  Future<void> _discover() => _run('discover(推荐)', () => _doDiscover());

  Future<void> _search(String query) => _run('search($query)', () => _doSearch(query));

  Future<void> _loadEpisodes() => _run('listEpisodes', _doEpisodes);

  Future<void> _resolve() => _run('resolvePlayback', _doResolve);

  /// 一键跑通：发现 → 分集 → 播放解析。
  Future<void> _runChain() => _run('全链路', () async {
        await _doDiscover();
        await _doEpisodes();
        await _doResolve();
      });

  Future<void> _resetDevice() => _run('resetDevice', () async {
        await OpenhongguoService.instance.resetDevice();
      });

  /// 音频诊断：读取 mpv 关键属性，定位「有画面没声音」。
  Future<void> _audioDiagnose() => _run('音频诊断', () async {
        final Player? player = _player;
        if (player == null) {
          throw StateError('尚未播放');
        }
        final dynamic platform = player.platform;
        Future<String> read(String prop) async {
          try {
            final Object? value = await platform.getProperty(prop);
            return '$prop = $value';
          } catch (error) {
            return '$prop <读取失败: $error>';
          }
        }

        for (final String prop in <String>[
          'ao-current', // 当前音频输出后端；= null 即吞音根因
          'aid', // 当前选中的音轨 id
          'mute',
          'volume',
          'audio-params', // 采样率/声道
          'track-list', // 媒体轨道列表
        ]) {
          _log(await read(prop));
        }
      });

  // ---------- 播放 ----------

  void _unmountPlayer() {
    _player?.dispose();
    _player = null;
    _videoController = null;
  }

  /// 渲染模式：模拟器上 mpv 的 vo=gpu 创建不了 GL 上下文，
  /// 改用 mediacodec_embed 让 MediaCodec 直接向 Surface 输出。
  /// 真机/失败时回落 vo=gpu；非 Android 平台（Windows 等）直接从
  /// gpu 起步，不走 embed 尝试。
  bool _useEmbedOutput = defaultVideoOutputMode() == VideoOutputMode.embed;

  String _lastVideoError = '-';

  Future<void> _play() async {
    final StreamInfo? stream = _selectedStream;
    if (stream == null || stream.url.isEmpty) {
      _log('没有可播放的流');
      return;
    }
    await _run('play(${stream.definition})', () async {
      final bool ok = await _startPlayback(stream, embed: _useEmbedOutput);
      if (!ok && _useEmbedOutput) {
        _log('mediacodec_embed 未出画面，回落 vo=gpu 重试');
        _useEmbedOutput = false;
        await _startPlayback(stream, embed: false);
      }
    });
  }

  /// 启动一次播放；返回是否真正出画面（解码推进 + 拿到视频尺寸）。
  Future<bool> _startPlayback(StreamInfo stream, {required bool embed}) async {
    _unmountPlayer();
    final Player player = Player();
    _player = player;
    _lastVideoError = '-';

    player.stream.error.listen((String e) {
      _lastVideoError = e;
      _log('MPV-ERROR $e');
    });
    player.stream.log.listen((PlayerLog e) {
      if (e.level.contains('error') || e.level.contains('warn')) {
        _log('MPV-LOG[${e.level}] ${e.prefix}: ${e.text}');
      }
    });

    // embed: MediaCodec 直出 Surface，绕开模拟器上失败的 vo=gpu(OpenGL)。
    // 回落：Android 真机用 gpu；桌面用 texture（render API 纹理渲染，
    // 桌面显式 vo=gpu 会让 mpv 弹独立原生窗口，W2 实测）。
    final VideoOutputMode mode = embed
        ? VideoOutputMode.embed
        : (defaultTargetPlatform == TargetPlatform.android
            ? VideoOutputMode.gpu
            : VideoOutputMode.texture);
    _videoController = VideoController(
      player,
      configuration: videoOutputConfiguration(mode),
    );
    _log('VideoController 就绪（vo=${mode.name}）');

    // 关键：先让 Video widget 挂载、Surface 就绪，再 open 媒体。
    // 否则 mpv 在 surface 为 NULL 时初始化 mediacodec 会失败。
    setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 400));

    // 加密流：内容密钥交给 ffmpeg 解复用层（与官方 CLI 同款属性）。
    // 解密发生在 demux 阶段，编码器收到的是明文，因此对硬解同样有效。
    final PlaybackBundle? bundle = _bundle;
    if (bundle != null && bundle.hasKey && stream.protected) {
      try {
        await (player.platform as dynamic).setProperty(
          'demuxer-lavf-o',
          'decryption_key=${bundle.contentKeyHex}',
        );
        _log('已设置 decryption_key（ffmpeg 解复用层）');
      } catch (error) {
        _log('设置解密参数失败: $error');
      }
    }

    // 官方 UA：mpv 默认 UA 拉视频 CDN 会被拒（W2 Windows 实测 + POC 结论）。
    try {
      await (player.platform as dynamic)
          .setProperty('user-agent', kCdnUserAgent);
    } catch (error) {
      _log('设置 UA 失败: $error');
    }

    await player.open(Media(stream.url));

    bool gotVideo = false;
    for (int i = 0; i < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) {
        break;
      }
      final Duration pos = player.state.position;
      final int? w = player.state.width;
      final int? h = player.state.height;
      _log(
        'STATE t+${(i + 1) * 800}ms pos=${pos.inMilliseconds}ms '
        'size=${w}x$h err=$_lastVideoError',
      );
      if (pos.inMilliseconds > 0 && w != null && h != null && w > 0) {
        gotVideo = true;
        break;
      }
    }
    return gotVideo;
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final double horizontal = horizontalPagePadding(context);
    final DataMode mode = ref.watch(dataModeProvider);

    return Scaffold(
      backgroundColor: colors.page,
      body: Column(
        children: <Widget>[
          const PageHeader(title: 'SDK 调试'),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 28),
              children: <Widget>[
                _Section(
                  title: '数据源',
                  child: Row(
                    children: <Widget>[
                      _ModeChip(
                        label: 'SDK 直连',
                        selected: mode == DataMode.sdk,
                        onTap: () => ref
                            .read(dataModeProvider.notifier)
                            .set(DataMode.sdk),
                      ),
                      const SizedBox(width: 8),
                      _ModeChip(
                        label: '演示数据',
                        selected: mode == DataMode.mock,
                        onTap: () => ref
                            .read(dataModeProvider.notifier)
                            .set(DataMode.mock),
                      ),
                    ],
                  ),
                ),
                _Section(
                  title: '① 发现 / 搜索',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _queryController,
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: '关键词，如：闪婚',
                              ),
                              onSubmitted: _search,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(label: '搜索', onTap: _busy ? null : () => _search(_queryController.text)),
                          const SizedBox(width: 8),
                          _ActionButton(label: '发现', onTap: _busy ? null : _discover),
                        ],
                      ),
                      const SizedBox(height: 9),
                      _ActionButton(label: '一键跑通（发现→分集→解析）', onTap: _busy ? null : _runChain),
                    ],
                  ),
                ),
                if (_series.isNotEmpty)
                  _Section(
                    title: '② 选剧（${_series.length}）',
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final Drama drama in _series.take(12))
                          _PickChip(
                            label: drama.title,
                            selected: identical(drama, _selectedSeries),
                            onTap: () => setState(() {
                              _selectedSeries = drama;
                              _selectedEpisode = null;
                              _bundle = null;
                              _selectedStream = null;
                            }),
                          ),
                      ],
                    ),
                  ),
                if (_selectedSeries != null)
                  _Section(
                    title: '③ 分集（${_episodes.length}）',
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        _ActionButton(
                          label: '加载分集',
                          onTap: _busy ? null : _loadEpisodes,
                        ),
                        for (final EpisodeInfo episode in _episodes.take(20))
                          _PickChip(
                            label: '${episode.number}',
                            selected: identical(episode, _selectedEpisode),
                            onTap: () => setState(() {
                              _selectedEpisode = episode;
                              _bundle = null;
                              _selectedStream = null;
                            }),
                          ),
                      ],
                    ),
                  ),
                if (_selectedEpisode != null)
                  _Section(
                    title: '④ 播放解析',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _ActionButton(label: '解析播放', onTap: _busy ? null : _resolve),
                        if (_bundle != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            '密钥: ${_bundle!.hasKey ? _bundle!.contentKeyHex : '无（未加密或解析失败）'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final StreamInfo s in _bundle!.streams)
                            _PickChip(
                              label: s.label,
                              selected: identical(s, _selectedStream),
                              onTap: () =>
                                  setState(() => _selectedStream = s),
                            ),
                        ],
                      ],
                    ),
                  ),
                if (_selectedStream != null)
                  _Section(
                    title: '⑤ 试播（media_kit）',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (_videoController != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Video(controller: _videoController!),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            _ActionButton(
                              label: '播放选中流',
                              onTap: _busy ? null : _play,
                            ),
                            const SizedBox(width: 8),
                            _ActionButton(
                              label: '停止',
                              onTap: _busy
                                  ? null
                                  : () {
                                      _unmountPlayer();
                                      setState(() {});
                                    },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                _Section(
                  title: '设备 / 日志',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          _ActionButton(label: '重置设备', onTap: _busy ? null : _resetDevice),
                          const SizedBox(width: 8),
                          _ActionButton(
                            label: '音频诊断',
                            onTap: _busy ? null : _audioDiagnose,
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            label: '清空日志',
                            onTap: () => setState(() => _logs.clear()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 220),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              for (final String line in _logs)
                                Text(
                                  line,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    height: 1.5,
                                    color: colors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.hairline, width: 0.8),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 9),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool enabled = onTap != null;
    return Material(
      color: enabled ? colors.brandStrong : colors.surfaceMuted,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: enabled ? colors.onBrand : colors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PickChip extends StatelessWidget {
  const _PickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Material(
      color: selected ? colors.brandStrong : colors.surfaceMuted,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? colors.onBrand : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Material(
      color: selected ? colors.brandStrong : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? colors.brandStrong : colors.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? colors.onBrand : colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
