// =============================================================================
// BRE4CH - Conflict Map View
// Interactive map with Iranian missile sites + GCC air defense layers
// Pattern: evac_screen.dart FlutterMap implementation
// =============================================================================

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/theme.dart';
import '../../data/missile_sites.dart';
import '../../data/air_defense_systems.dart';
import '../../models/missile_site.dart';
import '../../models/air_defense_system.dart';
import '../../services/cached_tile_provider.dart';
import '../../widgets/common/filter_chip_row.dart';
import 'missile_site_sheet.dart';
import 'air_defense_sheet.dart';
import 'conflict_map_legend.dart';

class ConflictMapView extends StatefulWidget {
  const ConflictMapView({super.key});

  @override
  State<ConflictMapView> createState() => _ConflictMapViewState();
}

class _ConflictMapViewState extends State<ConflictMapView> {
  final MapController _mapController = MapController();

  // Layer visibility
  bool _showMissileSites = true;
  bool _showAirDefense = true;

  // Missile status sub-filter
  final Set<String> _missileStatusFilter = {'ALL'};

  // Air defense country sub-filter
  final Set<String> _defenseCountryFilter = {'ALL'};

  // ── Filter labels ───────────────────────────────────────────────

  static const _missileStatusLabels = ['ALL', 'ACTIVE', 'DESTROYED', 'PARTIAL', 'UNKNOWN'];
  static const _defenseCountryLabels = [
    'ALL', 'UAE', 'Kuwait', 'Bahrain', 'Qatar', 'KSA', 'Oman', 'Israel', 'US',
  ];

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Layer toggles
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _buildLayerChip(
                'MISSILE SITES',
                Icons.rocket_launch,
                NatoColors.hostile,
                _showMissileSites,
                () => setState(() => _showMissileSites = !_showMissileSites),
              ),
              const SizedBox(width: 6),
              _buildLayerChip(
                'AIR DEFENSE',
                Icons.shield,
                NatoColors.friendly,
                _showAirDefense,
                () => setState(() => _showAirDefense = !_showAirDefense),
              ),
            ],
          ),
        ),

        // Sub-filters
        if (_showMissileSites)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: FilterChipRow(
              labels: _missileStatusLabels,
              selected: _missileStatusFilter,
              onToggle: _onMissileStatusToggle,
              activeColor: NatoColors.hostile,
            ),
          ),
        if (_showAirDefense)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: FilterChipRow(
              labels: _defenseCountryLabels,
              selected: _defenseCountryFilter,
              onToggle: _onDefenseCountryToggle,
              activeColor: NatoColors.friendly,
            ),
          ),

        // Map
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(30.0, 50.0),
                    initialZoom: 5,
                    minZoom: 3,
                    maxZoom: 18,
                    backgroundColor: const Color(0xFF0A0E17),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.breach',
                      retinaMode: true,
                      tileProvider: createCachedTileProvider(),
                    ),
                    MarkerLayer(markers: _buildAllMarkers()),
                  ],
                ),

                // Legend overlay
                if (_showMissileSites || _showAirDefense)
                  Positioned(
                    bottom: 30,
                    left: 8,
                    child: ConflictMapLegend(
                      showMissiles: _showMissileSites,
                      showDefense: _showAirDefense,
                    ),
                  ),

                // Attribution
                Positioned(
                  bottom: 4,
                  right: 8,
                  child: Text(
                    'CARTO / OpenStreetMap',
                    style: AppTextStyles.mono(
                      size: 9,
                      color: Palantir.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                ),

                // Stats summary
                Positioned(
                  top: 8,
                  right: 8,
                  child: _buildStatsSummary(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Stats summary overlay ────────────────────────────────────────

  Widget _buildStatsSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Palantir.bg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Palantir.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showMissileSites) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.rocket_launch, size: 10, color: NatoColors.hostile),
                const SizedBox(width: 4),
                Text(
                  '$missileSitesTotal SITES',
                  style: AppTextStyles.mono(size: 9, weight: FontWeight.w600, color: NatoColors.hostile),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '$missileSitesActive ACT / $missileSitesDestroyed DESTR / $missileSitesPartial PART',
              style: AppTextStyles.mono(size: 8, color: Palantir.textMuted),
            ),
          ],
          if (_showMissileSites && _showAirDefense)
            const SizedBox(height: 4),
          if (_showAirDefense) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield, size: 10, color: NatoColors.friendly),
                const SizedBox(width: 4),
                Text(
                  '$totalInterceptionsAllCoalition INTERCEPTS',
                  style: AppTextStyles.mono(size: 9, weight: FontWeight.w600, color: NatoColors.friendly),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Filter handlers ──────────────────────────────────────────────

  void _onMissileStatusToggle(String label) {
    setState(() {
      if (label == 'ALL') {
        _missileStatusFilter
          ..clear()
          ..add('ALL');
      } else {
        _missileStatusFilter.remove('ALL');
        if (_missileStatusFilter.contains(label)) {
          _missileStatusFilter.remove(label);
          if (_missileStatusFilter.isEmpty) _missileStatusFilter.add('ALL');
        } else {
          _missileStatusFilter.add(label);
        }
      }
    });
  }

  void _onDefenseCountryToggle(String label) {
    setState(() {
      if (label == 'ALL') {
        _defenseCountryFilter
          ..clear()
          ..add('ALL');
      } else {
        _defenseCountryFilter.remove('ALL');
        if (_defenseCountryFilter.contains(label)) {
          _defenseCountryFilter.remove(label);
          if (_defenseCountryFilter.isEmpty) _defenseCountryFilter.add('ALL');
        } else {
          _defenseCountryFilter.add(label);
        }
      }
    });
  }

  // ── Marker builders ──────────────────────────────────────────────

  List<Marker> _buildAllMarkers() {
    final markers = <Marker>[];

    if (_showMissileSites) {
      for (final site in _filteredMissileSites()) {
        markers.add(_buildMissileSiteMarker(site));
      }
    }

    if (_showAirDefense) {
      for (final system in _filteredAirDefenseSystems()) {
        markers.add(_buildAirDefenseMarker(system));
      }
    }

    return markers;
  }

  List<MissileSite> _filteredMissileSites() {
    if (_missileStatusFilter.contains('ALL')) return iranianMissileSites;
    return iranianMissileSites.where((site) {
      return _missileStatusFilter.contains(site.status.label);
    }).toList();
  }

  List<AirDefenseSystem> _filteredAirDefenseSystems() {
    if (_defenseCountryFilter.contains('ALL')) return coalitionAirDefense;
    return coalitionAirDefense.where((system) {
      return _defenseCountryFilter.contains(system.country);
    }).toList();
  }

  Marker _buildMissileSiteMarker(MissileSite site) {
    final color = _missileSiteColor(site.status);
    final icon = site.status == MissileSiteStatus.destroyed
        ? Icons.close
        : site.status == MissileSiteStatus.partiallyDestroyed
            ? Icons.warning_amber
            : Icons.rocket_launch;

    return Marker(
      point: LatLng(site.lat, site.lng),
      width: 32,
      height: 40,
      child: GestureDetector(
        onTap: () => showMissileSiteSheet(context, site),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Icon(icon, size: 12, color: Colors.white),
              ),
            ),
            CustomPaint(
              size: const Size(8, 6),
              painter: _TrianglePainter(color),
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildAirDefenseMarker(AirDefenseSystem system) {
    return Marker(
      point: LatLng(system.lat, system.lng),
      width: 32,
      height: 40,
      child: GestureDetector(
        onTap: () => showAirDefenseSheet(context, system),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: NatoColors.friendly.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: NatoColors.friendly.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.shield, size: 12, color: Colors.white),
              ),
            ),
            CustomPaint(
              size: const Size(8, 6),
              painter: _TrianglePainter(NatoColors.friendly),
            ),
          ],
        ),
      ),
    );
  }

  // ── Layer chip builder ────────────────────────────────────────────

  Widget _buildLayerChip(
    String label,
    IconData icon,
    Color color,
    bool active,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.15)
                : Palantir.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: 0.5)
                  : Palantir.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 11, color: active ? color : Palantir.textMuted),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.mono(
                  size: 9,
                  weight: FontWeight.w600,
                  color: active ? color : Palantir.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Color helpers ─────────────────────────────────────────────────

  Color _missileSiteColor(MissileSiteStatus status) {
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
}

// ── Triangle pointer painter (same as evac_screen) ──────────────────

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.9);
    final path = ui.Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}
