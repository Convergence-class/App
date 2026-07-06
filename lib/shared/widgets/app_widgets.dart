import 'package:flutter/material.dart';

import 'package:emotion_app/core/theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 22 : 30,
          height: compact ? 22 : 30,
          decoration: const BoxDecoration(
            color: AppColors.amber,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.eco_rounded,
            color: Colors.white,
            size: compact ? 14 : 18,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          '마인드밸런스',
          style: TextStyle(
            color: AppColors.amber,
            fontWeight: FontWeight.w800,
            fontSize: compact ? 12 : 15,
          ),
        ),
      ],
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.title, this.showLogo = true});

  final String title;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 12),
      child: Row(
        children: [
          if (showLogo) const AppLogo(compact: true),
          if (showLogo) const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          const Icon(Icons.notifications_none_rounded, size: 22),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.blueSoft,
            child: const Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class DesignCard extends StatelessWidget {
  const DesignCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.fromLTRB(20, 0, 20, 14),
    this.color = AppColors.card,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: child,
    );
  }
}

class YellowButton extends StatelessWidget {
  const YellowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: filled ? AppColors.amber : AppColors.surface,
          foregroundColor: filled ? Colors.white : AppColors.navy,
          side: filled
              ? BorderSide.none
              : const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class UsageRow extends StatelessWidget {
  const UsageRow({
    super.key,
    required this.initials,
    required this.name,
    required this.time,
    required this.color,
    required this.progress,
  });

  final String initials;
  final String name;
  final String time;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: progress,
                    backgroundColor: AppColors.line,
                    valueColor: const AlwaysStoppedAnimation(AppColors.blue),
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

class MiniBarChart extends StatelessWidget {
  const MiniBarChart({super.key, required this.values, this.compact = false});

  final List<double> values;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: compact ? 92 : 118,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (index) {
          final isPeak = index == 5 || index == 14 || index == 15;
          return Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: (values[index] / maxValue).clamp(0.12, 1.0),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isPeak ? AppColors.amber : const Color(0xffbee2ff),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
