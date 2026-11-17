import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class UnderlineTabs extends StatelessWidget {
  const UnderlineTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.dense = false,
    this.showDivider = true,
    this.spacing = 24,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool dense;
  final bool showDivider;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colors.hairline, width: 0.8))
            : null,
      ),
      padding: const EdgeInsets.only(left: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (int i = 0; i < labels.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  right: i == labels.length - 1 ? 0 : spacing,
                ),
                child: _TabItem(
                  label: labels[i],
                  selected: i == selectedIndex,
                  dense: dense,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.selected,
    required this.dense,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.only(top: dense ? 8 : 10, bottom: dense ? 5 : 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                style: TextStyle(
                  fontSize: dense ? 13.5 : 14.5,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.textPrimary : colors.textSecondary,
                ),
                child: Text(label),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? 18 : 0,
                height: 2.5,
                decoration: BoxDecoration(
                  color: colors.brand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
