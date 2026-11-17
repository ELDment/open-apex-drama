import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/membership_plan.dart';
import '../theme/app_colors.dart';
import '../widgets/app_pill_button.dart';
import '../widgets/page_header.dart';
import '../widgets/page_layout.dart';
import 'placeholder_screen.dart';

void openMembership(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext _) => const MembershipScreen(),
    ),
  );
}

class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen> {
  int _selectedPlan = 0;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool isDark = context.isDark;
    final double horizontal = horizontalPagePadding(context);

    return Scaffold(
      backgroundColor: colors.page,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const <Color>[Color(0xFF1B140C), Color(0xFF100E0C)]
                : const <Color>[Color(0xFFFFF6E4), Color(0xFFFFFBF5)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned(
              top: -150,
              right: -90,
              child: _GoldOrb(
                size: 340,
                color: AppTokens.gold.withValues(alpha: isDark ? 0.10 : 0.18),
              ),
            ),
            Positioned(
              bottom: -170,
              left: -130,
              child: _GoldOrb(
                size: 360,
                color: AppTokens.gold.withValues(alpha: isDark ? 0.06 : 0.12),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  const PageHeader(title: '开通会员'),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        6,
                        horizontal,
                        28,
                      ),
                      child: Column(
                        children: <Widget>[
                          const _Crown(),
                          const SizedBox(height: 16),
                          Text(
                            '尊享会员特权',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '免广告 · 看全集 · 专属内容',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 184,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                for (
                                  int i = 0;
                                  i < mockMembershipPlans.length;
                                  i++
                                )
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        top: 8,
                                        right:
                                            i == mockMembershipPlans.length - 1
                                            ? 0
                                            : 10,
                                      ),
                                      child: _PlanCard(
                                        plan: mockMembershipPlans[i],
                                        selected: i == _selectedPlan,
                                        onTap: () =>
                                            setState(() => _selectedPlan = i),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          AppPillButton(
                            label: '立即开通',
                            onPressed: () => openPlaceholder(
                              context,
                              title: '会员开通',
                              icon: Icons.workspace_premium_rounded,
                              message: '支付能力将在后续版本接入，当前为界面演示',
                            ),
                            tone: AppButtonTone.gold,
                            expand: true,
                            height: 52,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            horizontalPadding: 20,
                          ),
                          const SizedBox(height: 14),
                          Text.rich(
                            TextSpan(
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.6,
                                color: colors.textTertiary,
                              ),
                              children: <TextSpan>[
                                const TextSpan(text: '购买前同意'),
                                TextSpan(
                                  text: '《会员服务协议》',
                                  style: TextStyle(
                                    color: colors.goldText,
                                    decoration: TextDecoration.underline,
                                    decorationColor: colors.goldText,
                                  ),
                                ),
                                const TextSpan(text: '，开通后自动续费，可随时取消'),
                              ],
                            ),
                            textAlign: TextAlign.center,
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
    );
  }
}

class _Crown extends StatelessWidget {
  const _Crown();

  @override
  Widget build(BuildContext context) {
    final bool isDark = context.isDark;
    return SizedBox(
      width: 140,
      height: 124,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  AppTokens.gold.withValues(alpha: isDark ? 0.22 : 0.32),
                  AppTokens.gold.withValues(alpha: 0),
                ],
              ),
            ),
          ),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTokens.gradientCrown,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppTokens.gold.withValues(alpha: 0.35),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 47,
              color: Color(0xFF6B4300),
            ),
          ),
          Positioned(
            top: 8,
            right: 6,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: AppTokens.goldDeep.withValues(alpha: 0.85),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 8,
            child: Icon(
              Icons.circle,
              size: 5,
              color: AppTokens.goldDeep.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final MembershipPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final bool isDark = context.isDark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const <Color>[Color(0xFF352512), Color(0xFF241B10)]
                      : const <Color>[Color(0xFFFFF5E2), Color(0xFFFFE7C1)],
                )
              : null,
          color: selected
              ? null
              : colors.surface.withValues(alpha: isDark ? 1 : 0.74),
          border: Border.all(
            color: selected ? AppTokens.goldDeep : colors.hairline,
            width: selected ? 1.5 : 0.8,
          ),
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppTokens.gold.withValues(alpha: 0.20),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            if (plan.recommended)
              Positioned(
                top: -8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      gradient: colors.brandGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '限时特惠',
                      style: TextStyle(
                        fontSize: 8,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? AppTokens.goldDeep
                            : colors.textTertiary,
                        width: 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: selected
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTokens.goldDeep,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: selected ? colors.goldText : colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: '¥',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: plan.price,
                          style: TextStyle(
                            fontSize: 27,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '¥${plan.originalPrice}',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      color: colors.textTertiary,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    plan.period,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1.2,
                      color: colors.textSecondary,
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

class _GoldOrb extends StatelessWidget {
  const _GoldOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
