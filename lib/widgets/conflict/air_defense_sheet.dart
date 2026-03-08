// =============================================================================
// BRE4CH - Air Defense System Detail Bottom Sheet
// POI tap → detail panel for GCC/Coalition air defense systems
// =============================================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../models/air_defense_system.dart';
import '../../data/air_defense_systems.dart';

void showAirDefenseSheet(BuildContext context, AirDefenseSystem system) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Palantir.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Palantir.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Category + country badges
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _badge('AIR DEFENSE', NatoColors.friendly),
                _badge(
                  '${system.countryFlag} ${system.country}',
                  Palantir.accent,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // System name
            Text(
              system.name,
              style: AppTextStyles.sans(
                size: 18, weight: FontWeight.w700, color: Palantir.text,
              ),
            ),
            const SizedBox(height: 12),

            // Defense systems chips
            Text(
              'SYSTEMS',
              style: AppTextStyles.mono(
                size: 10, weight: FontWeight.w600,
                color: Palantir.textMuted, letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: system.systems
                  .map((s) => _badge(s.label, NatoColors.friendly))
                  .toList(),
            ),
            const SizedBox(height: 12),

            // Operator + Base
            _infoRow(Icons.military_tech, 'OPERATOR', system.operator),
            const SizedBox(height: 6),
            if (system.baseName != null)
              _infoRow(Icons.location_city, 'BASE', system.baseName!),
            if (system.baseName != null) const SizedBox(height: 6),
            _infoRow(
              Icons.location_on,
              'COORDS',
              '${system.lat.toStringAsFixed(4)}\u00B0N, ${system.lng.toStringAsFixed(4)}\u00B0E',
            ),
            const SizedBox(height: 12),

            // Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Palantir.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Palantir.border),
              ),
              child: Text(
                system.description,
                style: AppTextStyles.sans(size: 13, color: Palantir.text),
              ),
            ),
            const SizedBox(height: 16),

            // ── Interception Stats ─────────────────────────────────
            _buildInterceptionStats(system.stats),

            const SizedBox(height: 16),

            // Source link
            _sourceButton(
              icon: Icons.verified,
              label: 'SRC: ${system.sourceLabel}',
              color: Palantir.accent,
              onTap: () => _openUrl(system.sourceUrl),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

// ── Interception Stats Card ─────────────────────────────────────────

Widget _buildInterceptionStats(InterceptionStats stats) {
  // Compute daily average
  final now = DateTime.now().toUtc();
  final daysSinceMission = now.difference(missionStart).inDays;
  final dailyAvg = daysSinceMission > 0
      ? stats.totalIntercepted / daysSinceMission
      : stats.totalIntercepted.toDouble();

  final maxVal = [
    stats.ballisticIntercepted,
    stats.cruiseIntercepted,
    stats.droneIntercepted,
  ].reduce((a, b) => a > b ? a : b);

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: NatoColors.friendly.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: NatoColors.friendly.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shield, size: 14, color: NatoColors.friendly),
            const SizedBox(width: 6),
            Text(
              'INTERCEPTION STATS SINCE D+0',
              style: AppTextStyles.mono(
                size: 10,
                weight: FontWeight.w700,
                color: NatoColors.friendly,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Ballistic
        _statBar(
          'BALLISTIC',
          stats.ballisticIntercepted,
          maxVal,
          AttackColors.ballistic,
        ),
        const SizedBox(height: 8),

        // Cruise
        _statBar(
          'CRUISE',
          stats.cruiseIntercepted,
          maxVal,
          AttackColors.cruise,
        ),
        const SizedBox(height: 8),

        // Drones
        _statBar(
          'DRONES',
          stats.droneIntercepted,
          maxVal,
          AttackColors.drone,
        ),

        const SizedBox(height: 12),
        Divider(color: Palantir.border, height: 1),
        const SizedBox(height: 12),

        // Total + daily average
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL',
                    style: AppTextStyles.mono(
                      size: 9, weight: FontWeight.w600,
                      color: Palantir.textMuted, letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stats.totalIntercepted}',
                    style: AppTextStyles.mono(
                      size: 22, weight: FontWeight.w700, color: Palantir.accent,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAILY AVG',
                    style: AppTextStyles.mono(
                      size: 9, weight: FontWeight.w600,
                      color: Palantir.textMuted, letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '~${dailyAvg.toStringAsFixed(1)}/day',
                    style: AppTextStyles.mono(
                      size: 22, weight: FontWeight.w700, color: Palantir.cyan,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAYS',
                    style: AppTextStyles.mono(
                      size: 9, weight: FontWeight.w600,
                      color: Palantir.textMuted, letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'D+$daysSinceMission',
                    style: AppTextStyles.mono(
                      size: 22, weight: FontWeight.w700, color: Palantir.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Last updated: ${stats.lastUpdated}',
          style: AppTextStyles.mono(size: 9, color: Palantir.textMuted),
        ),
      ],
    ),
  );
}

// ── Stat bar row ────────────────────────────────────────────────────

Widget _statBar(String label, int value, int maxVal, Color color) {
  final fraction = maxVal > 0 ? value / maxVal : 0.0;

  return Row(
    children: [
      SizedBox(
        width: 70,
        child: Text(
          label,
          style: AppTextStyles.mono(
            size: 9, weight: FontWeight.w600,
            color: Palantir.textMuted, letterSpacing: 0.8,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: Palantir.border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 40,
        child: Text(
          '$value',
          textAlign: TextAlign.right,
          style: AppTextStyles.mono(
            size: 11, weight: FontWeight.w700, color: color,
          ),
        ),
      ),
    ],
  );
}

// ── Helpers ─────────────────────────────────────────────────────────

Widget _badge(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      text,
      style: AppTextStyles.mono(
        size: 9, weight: FontWeight.w700, color: color, letterSpacing: 1.0,
      ),
    ),
  );
}

Widget _infoRow(IconData icon, String label, String value) {
  return Row(
    children: [
      Icon(icon, size: 12, color: Palantir.textMuted),
      const SizedBox(width: 6),
      Text(
        '$label: ',
        style: AppTextStyles.mono(
          size: 10, weight: FontWeight.w600, color: Palantir.textMuted, letterSpacing: 1.0,
        ),
      ),
      Flexible(
        child: Text(
          value,
          style: AppTextStyles.mono(size: 11, color: Palantir.text),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

Widget _sourceButton({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.mono(
                size: 10, weight: FontWeight.w700, color: color, letterSpacing: 1.0,
              ),
            ),
          ),
          Icon(Icons.open_in_new, size: 12, color: color),
        ],
      ),
    ),
  );
}

void _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
