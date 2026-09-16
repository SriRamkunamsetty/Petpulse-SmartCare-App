import 'package:flutter/material.dart';
import '../models/connectivity_state.dart';
import '../theme/app_theme.dart';
import 'pp_card.dart';

/// Home-screen connectivity banner for the four non-`online` states —
/// mirrors `bannerMap` in the .dc.html prototype.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key, required this.banner});
  final ConnBanner banner;

  @override
  Widget build(BuildContext context) {
    return PpCard(
      elevation: PpCardElevation.sm,
      color: banner.bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child:
                Icon(Icons.warning_amber_rounded, size: 18, color: banner.fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(banner.title,
                    style: ppBody(
                        size: 13, weight: FontWeight.w700, color: banner.fg)),
                const SizedBox(height: 1),
                Text(banner.detail,
                    style: ppBody(
                        size: 12, color: banner.fg.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PpDot extends StatelessWidget {
  const PpDot({super.key, required this.color, this.size = 7});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
