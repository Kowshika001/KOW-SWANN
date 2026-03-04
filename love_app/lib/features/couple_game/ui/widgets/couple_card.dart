import 'package:flutter/material.dart';

class CoupleCard extends StatelessWidget {
  const CoupleCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.93),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: Colors.purple.withValues(alpha: 0.28),
      child: Padding(padding: padding, child: child),
    );
  }
}
