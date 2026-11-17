import 'package:flutter/foundation.dart';

import 'drama.dart';

@immutable
class WatchRecord {
  const WatchRecord({
    required this.drama,
    required this.progress,
    this.lastEpisode = 1,
  });

  final Drama drama;

  /// 0.0 - 1.0
  final double progress;

  /// Episode the user stopped at.
  final int lastEpisode;

  String get progressLabel => '看到 ${(progress * 100).round()}%';

  String get episodeLabel => '看到第 $lastEpisode 集 / 共 ${drama.episodes} 集';

  String get percentLabel => '${(progress * 100).round()}%';
}
