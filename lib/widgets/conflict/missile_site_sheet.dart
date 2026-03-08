// =============================================================================
// BRE4CH - Missile Site Detail Bottom Sheet
// POI tap → detail panel for Iranian missile launch sites
// =============================================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../models/missile_site.dart';

void showMissileSiteSheet(BuildContext context, MissileSite site) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Palantir.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.55,
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

            // Status + type badges
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _badge('MISSILE SITE', NatoColors.hostile),
                _badge(site.status.label, _statusColor(site.status)),
                _badge(site.type.label, Palantir.textMuted),
                _badge(site.country, Palantir.accent),
              ],
            ),
            const SizedBox(height: 12),

            // Site name
            Text(
              site.name,
              style: AppTextStyles.sans(
                size: 18, weight: FontWeight.w700, color: Palantir.text,
              ),
            ),
            if (site.nameLocal.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                site.nameLocal,
                style: AppTextStyles.sans(size: 14, color: Palantir.textMuted),
                textDirection: TextDirection.rtl,
              ),
            ],
            const SizedBox(height: 12),

            // Operator + Coords
            _infoRow(Icons.military_tech, 'OPERATOR', site.operator),
            const SizedBox(height: 6),
            _infoRow(
              Icons.location_on,
              'COORDS',
              '${site.lat.toStringAsFixed(4)}\u00B0N, ${site.lng.toStringAsFixed(4)}\u00B0E',
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
                site.description,
                style: AppTextStyles.sans(size: 13, color: Palantir.text),
              ),
            ),

            // Strike details (if destroyed/partial)
            if (site.lastStrikeDate != null || site.strikeDetails != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: StatusColors.neutralized.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: StatusColors.neutralized.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.gps_fixed, size: 12, color: StatusColors.neutralized),
                        const SizedBox(width: 6),
                        Text(
                          'STRIKE ASSESSMENT',
                          style: AppTextStyles.mono(
                            size: 10,
                            weight: FontWeight.w700,
                            color: StatusColors.neutralized,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    if (site.lastStrikeDate != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'DATE: ${site.lastStrikeDate}',
                        style: AppTextStyles.mono(size: 11, color: Palantir.text),
                      ),
                    ],
                    if (site.strikeDetails != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        site.strikeDetails!,
                        style: AppTextStyles.sans(size: 12, color: Palantir.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Source link
            _sourceButton(
              icon: Icons.verified,
              label: 'SRC: ${site.sourceLabel}',
              color: Palantir.accent,
              onTap: () => _openUrl(site.sourceUrl),
            ),

            // Satellite imagery link
            if (site.photoUrl != null) ...[
              const SizedBox(height: 8),
              _sourceButton(
                icon: Icons.satellite_alt,
                label: 'SATELLITE IMAGERY',
                color: Palantir.cyan,
                onTap: () => _openUrl(site.photoUrl!),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
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

Color _statusColor(MissileSiteStatus status) {
  switch (status) {
    case MissileSiteStatus.active:
      return StatusColors.active;
    case MissileSiteStatus.destroyed:
      return StatusColors.neutralized;
    case MissileSiteStatus.partiallyDestroyed:
      return StatusColors.damaged;
    case MissileSiteStatus.unknown:
      return StatusColors.unknown;
  }
}

void _openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
