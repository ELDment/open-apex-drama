import 'package:flutter/foundation.dart';

@immutable
class MembershipPlan {
  const MembershipPlan({
    required this.name,
    required this.price,
    required this.originalPrice,
    required this.period,
    this.recommended = false,
  });

  final String name;
  final String price;
  final String originalPrice;
  final String period;
  final bool recommended;
}
