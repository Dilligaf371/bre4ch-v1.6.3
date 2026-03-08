// =============================================================================
// BRE4CH - Conflict Map Legend
// Translucent overlay showing marker color meanings
// =============================================================================

import 'package:flutter/material.dart';
import '../../config/theme.dart';

class ConflictMapLegend extends StatelessWidget {
  final bool showMissiles;
  final bool showDefense;

  const ConflictMapLegend({
    super.key,
    required this.showMissiles,
    required this.showDefense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Palantir.bg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Palantir.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showMissiles) ...[
            Text(
              'STRIKE TARGETS',
              style: AppTextStyles.mono(
                size: 8,
                weight: FontWeight.w700,
                color: NatoColors.hostile,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            _legendDot(StatusColors.active, 'ACTIVE'),
            _legendDotRing(StatusColors.destroyed, NatoColors.hostile, 'DESTROYED'),
            _legendDot(StatusColors.damaged, 'PARTIAL'),
            _legendDot(StatusColors.unknown, 'UNKNOWN'),
          ],
          if (showMissiles && showDefense) const SizedBox(height: 6),
          if (showDefense) ...[
            Text(
              'AIR DEFENSE',
              style: AppTextStyles.mono(
                size: 8,
                weight: FontWeight.w700,
                color: NatoColors.friendly,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            _legendDot(NatoColors.friendly, 'COALITION'),
          ],
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.mono(size: 8, color: Palantir.textMuted),
          ),
        ],
      ),
    );
  }

  /// NATO destroyed indicator: grey dot with red ring border
  Widget _legendDotRing(Color fill, Color ring, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: ring, width: 1.5),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.mono(size: 8, color: Palantir.textMuted),
          ),
        ],
      ),
    );
  }
}
