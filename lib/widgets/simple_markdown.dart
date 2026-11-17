import 'package:flutter/material.dart';

/// Release notes 的轻量 Markdown 渲染（够用即可，不引第三方解析库）。
///
/// 支持：`#`/`##`/`###` 标题、`-`/`*` 无序列表、`1.` 有序列表、
/// 行内 `**加粗**` 与 `` `代码` ``、链接 `[文字](url)` 只显示文字。
/// 其余行按普通段落。
class SimpleMarkdown extends StatelessWidget {
  const SimpleMarkdown(this.data, {super.key, this.baseStyle});

  final String data;
  final TextStyle? baseStyle;

  @override
  Widget build(BuildContext context) {
    final TextStyle fallback =
        baseStyle ?? const TextStyle(fontSize: 13, height: 1.55);
    final List<Widget> blocks = <Widget>[];
    for (final String rawLine in data.split('\n')) {
      final String line = rawLine.trimRight();
      if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: 8));
        continue;
      }
      final String trimmed = line.trim();
      // 标题：# / ## / ###
      final RegExpMatch? heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(
        trimmed,
      );
      if (heading != null) {
        final int level = heading.group(1)!.length;
        blocks.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text(
            _plain(heading.group(2)!),
            style: fallback.copyWith(
              fontSize: fallback.fontSize! + (4 - level),
              fontWeight: FontWeight.w700,
            ),
          ),
        ));
        continue;
      }
      // 无序列表
      final RegExpMatch? bullet = RegExp(r'^[-*•]\s+(.*)$').firstMatch(trimmed);
      if (bullet != null) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (fallback.color ?? Colors.grey).withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  _inline(bullet.group(1)!, fallback),
                ),
              ),
            ],
          ),
        ));
        continue;
      }
      // 有序列表：保留「1. 」原样作为段落（缩进对齐）
      final RegExpMatch? ordered = RegExp(r'^(\d+[.、)])\s+(.*)$').firstMatch(
        trimmed,
      );
      if (ordered != null) {
        blocks.add(Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 3),
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '${ordered.group(1)} ',
                  style: fallback.copyWith(fontWeight: FontWeight.w600),
                ),
                ..._inline(ordered.group(2)!, fallback).children!,
              ],
            ),
          ),
        ));
        continue;
      }
      blocks.add(Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text.rich(_inline(trimmed, fallback)),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  /// 去掉行内的 md 标记（用于标题等纯文本位置）。
  static String _plain(String text) {
    return text
        .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (Match m) => m.group(1)!)
        .replaceAllMapped(RegExp(r'`(.+?)`'), (Match m) => m.group(1)!)
        .replaceAllMapped(
          RegExp(r'\[(.+?)\]\((.+?)\)'),
          (Match m) => m.group(1)!,
        );
  }

  /// 行内标记 → TextSpan：**加粗**、`代码`、[文字](url) 只留文字。
  static TextSpan _inline(String text, TextStyle base) {
    final List<InlineSpan> spans = <InlineSpan>[];
    final RegExp pattern = RegExp(
      r'\*\*(.+?)\*\*|`(.+?)`|\[(.+?)\]\((.+?)\)',
    );
    int cursor = 0;
    for (final RegExpMatch match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final String? bold = match.group(1);
      final String? code = match.group(2);
      final String? linkText = match.group(3);
      if (bold != null) {
        spans.add(
          TextSpan(
            text: bold,
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (code != null) {
        spans.add(
          TextSpan(
            text: code,
            style: base.copyWith(
              fontFamily: 'monospace',
              fontSize: (base.fontSize ?? 13) - 1,
              backgroundColor:
                  (base.color ?? Colors.grey).withValues(alpha: 0.10),
            ),
          ),
        );
      } else if (linkText != null) {
        spans.add(TextSpan(text: linkText));
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: base, children: spans);
  }
}
