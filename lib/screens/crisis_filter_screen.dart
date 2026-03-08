// =============================================================================
// BRE4CH - Crisis Filter Screen (TRUTH)
// EVENTS / OSINT / CENTCOM / LIVE TV / TOOLS tabs
// BRE4CH
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/attack_event.dart';
import '../models/centcom_briefing.dart';
import '../models/osint_item.dart';
import '../providers/centcom_provider.dart';
import '../providers/event_feed_provider.dart';
import '../providers/osint_provider.dart';
import '../utils/formatters.dart';
import '../widgets/common/filter_chip_row.dart';
import '../widgets/common/header_bar.dart';
import '../widgets/common/palantir_card.dart';
import '../widgets/common/status_badge.dart';
import '../widgets/common/priority_badge.dart';
import '../widgets/common/pulsing_dot.dart';



class CrisisFilterScreen extends ConsumerStatefulWidget {
  const CrisisFilterScreen({super.key});

  @override
  ConsumerState<CrisisFilterScreen> createState() => _CrisisFilterScreenState();
}

class _CrisisFilterScreenState extends ConsumerState<CrisisFilterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final Set<String> _centcomCategoryFilter = {};

  // EVENTS filters
  final Set<String> _eventCountryFilter = {};
  final Set<String> _eventSourceFilter = {};
  final Set<String> _eventStatusFilter = {};

  // OSINT filters
  final Set<String> _osintCountryFilter = {};
  final Set<String> _osintPriorityFilter = {};
  final Set<String> _osintSourceFilter = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palantir.bg,
      body: SafeArea(
        child: Column(
          children: [
            const HeaderBar(),
            TabBar(
              controller: _tabCtrl,
              labelColor: Palantir.accent,
              unselectedLabelColor: Palantir.textMuted,
              indicatorColor: Palantir.accent,
              indicatorSize: TabBarIndicatorSize.label,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelStyle: AppTextStyles.mono(
                size: 11,
                weight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
              tabs: const [
                Tab(text: 'EVENTS'),
                Tab(text: 'OSINT'),
                Tab(text: 'CENTCOM'),
                Tab(text: 'LIVE TV'),
                Tab(text: 'TOOLS'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildEventsTab(),
                  _buildOsintTab(),
                  _buildCentcomTab(),
                  _buildLiveTvTab(),
                  _buildToolsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── EVENTS TAB ───────────────────────────────────────────────────

  String _eventCountryFromTarget(String target) {
    final lower = target.toLowerCase();
    if (lower.contains('uae') || lower.contains('dubai') || lower.contains('abu dhabi') || lower.contains('sharjah') || lower.contains('emirates') || lower.contains('الإمارات')) return 'UAE';
    if (lower.contains('israel') || lower.contains('tel aviv') || lower.contains('jerusalem')) return 'ISRAEL';
    if (lower.contains('iran') || lower.contains('tehran') || lower.contains('isfahan') || lower.contains('natanz')) return 'IRAN';
    if (lower.contains('ksa') || lower.contains('riyadh') || lower.contains('saudi') || lower.contains('jeddah')) return 'KSA';
    if (lower.contains('kuwait')) return 'KUWAIT';
    if (lower.contains('bahrain') || lower.contains('manama')) return 'BAHRAIN';
    if (lower.contains('qatar') || lower.contains('doha')) return 'QATAR';
    if (lower.contains('oman') || lower.contains('muscat')) return 'OMAN';
    if (lower.contains('jordan') || lower.contains('amman')) return 'JORDAN';
    if (lower.contains('lebanon') || lower.contains('beirut')) return 'LEBANON';
    if (lower.contains('iraq') || lower.contains('baghdad') || lower.contains('pmf')) return 'IRAQ';
    if (lower.contains('syria') || lower.contains('damascus')) return 'SYRIA';
    if (lower.contains('yemen') || lower.contains('houthi') || lower.contains('sanaa')) return 'YEMEN';
    if (lower.contains('usa') || lower.contains('centcom') || lower.contains('pentagon') || lower.contains('washington')) return 'USA';
    if (lower.contains('uk') || lower.contains('britain') || lower.contains('london')) return 'UK';
    if (lower.contains('france') || lower.contains('paris') || lower.contains('french')) return 'FRANCE';
    return 'OTHER';
  }

  /// Returns ALL matching source categories (set-based).
  /// An event like "X @modgovae" matches both 'X' and 'MOD'.
  Set<String> _eventSourceCategories(String? source) {
    if (source == null) return {'OTHER'};
    final s = source.toUpperCase();
    final cats = <String>{};
    // Platform detection
    if (s.contains('@') || s.startsWith('X ') || s.contains('X.COM') || s.contains('TWITTER')) cats.add('X');
    if (s.contains('INSTAGRAM') || s.contains(' IG') || s.startsWith('IG ')) cats.add('IG');
    // Entity detection
    if (s.contains('MOI') || s.contains('INTERIOR') || s.contains('الداخلية')) cats.add('MOI');
    if (s.contains('MOD') || s.contains('DEFENSE') || s.contains('DEFENCE') || s.contains('الدفاع')) cats.add('MOD');
    if (s.contains('MOFA') || s.contains('FOREIGN') || s.contains('الخارجية')) cats.add('MOFA');
    if (s.contains('NCEMA')) cats.add('NCEMA');
    if (s.contains('CENTCOM')) cats.add('CENTCOM');
    if (s.contains('IDF')) cats.add('IDF');
    if (cats.isEmpty) cats.add('COALITION');
    return cats;
  }

  String _eventStatusLabel(EventStatus s) {
    switch (s) {
      case EventStatus.intercepted: return 'INTERCEPTED';
      case EventStatus.impact: return 'IMPACT';
      case EventStatus.ongoing: return 'ONGOING';
      case EventStatus.neutralized: return 'NEUTRALIZED';
    }
  }

  List<AttackEvent> _filteredEvents(List<AttackEvent> events) {
    var result = events;
    if (_eventCountryFilter.isNotEmpty) {
      result = result.where((e) => _eventCountryFilter.contains(_eventCountryFromTarget(e.target))).toList();
    }
    if (_eventSourceFilter.isNotEmpty) {
      result = result.where((e) =>
        _eventSourceCategories(e.source).intersection(_eventSourceFilter).isNotEmpty
      ).toList();
    }
    if (_eventStatusFilter.isNotEmpty) {
      result = result.where((e) => _eventStatusFilter.contains(_eventStatusLabel(e.status))).toList();
    }
    return result;
  }

  Widget _buildEventsTab() {
    final events = ref.watch(eventFeedProvider);
    final filtered = _filteredEvents(events);

    return Column(
      children: [
        const SizedBox(height: 8),
        // Country filter
        FilterChipRow(
          labels: const ['UAE', 'KSA', 'KUWAIT', 'BAHRAIN', 'QATAR', 'OMAN', 'JORDAN', 'ISRAEL', 'IRAN', 'LEBANON', 'IRAQ', 'SYRIA', 'YEMEN', 'USA', 'UK', 'FRANCE'],
          selected: _eventCountryFilter,
          onToggle: (label) => setState(() {
            _eventCountryFilter.contains(label) ? _eventCountryFilter.remove(label) : _eventCountryFilter.add(label);
          }),
          activeColor: Palantir.accent,
        ),
        const SizedBox(height: 4),
        // Source filter
        FilterChipRow(
          labels: const ['MOI', 'MOD', 'MOFA', 'NCEMA', 'CENTCOM', 'IDF', 'X', 'IG', 'COALITION'],
          selected: _eventSourceFilter,
          onToggle: (label) => setState(() {
            _eventSourceFilter.contains(label) ? _eventSourceFilter.remove(label) : _eventSourceFilter.add(label);
          }),
          activeColor: Palantir.info,
        ),
        const SizedBox(height: 4),
        // Status filter
        FilterChipRow(
          labels: const ['INTERCEPTED', 'IMPACT', 'ONGOING', 'NEUTRALIZED'],
          selected: _eventStatusFilter,
          onToggle: (label) => setState(() {
            _eventStatusFilter.contains(label) ? _eventStatusFilter.remove(label) : _eventStatusFilter.add(label);
          }),
          activeColor: Palantir.warning,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            color: Palantir.accent,
            backgroundColor: Palantir.surface,
            onRefresh: () => ref.read(eventFeedProvider.notifier).refresh(),
            child: filtered.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.radar, size: 32, color: Palantir.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              events.isEmpty ? 'MONITORING EVENT FEED...' : 'NO EVENTS MATCH FILTERS',
                              style: AppTextStyles.mono(size: 10, color: Palantir.textMuted, letterSpacing: 1.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              events.isEmpty ? 'Live events will appear here' : 'Adjust filters above',
                              style: AppTextStyles.sans(size: 11, color: Palantir.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _buildEventCard(filtered[index]);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(AttackEvent event) {
    final hasUrl = event.sourceUrl != null && event.sourceUrl!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: hasUrl ? () => _openUrl(event.sourceUrl!) : null,
        child: PalantirCard(
        borderColor: event.status == EventStatus.ongoing
            ? Palantir.warning.withValues(alpha: 0.5)
            : event.status == EventStatus.impact
                ? Palantir.danger.withValues(alpha: 0.5)
                : null,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: type icon, origin -> target, status
            Row(
              children: [
                _attackTypeIcon(event.type),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${event.origin} \u2192 ${event.target}',
                        style: AppTextStyles.mono(
                          size: 10,
                          weight: FontWeight.w600,
                          color: Palantir.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _attackTypeLabel(event.type),
                        style: AppTextStyles.mono(
                          size: 10,
                          color: _attackTypeColor(event.type),
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: event.status),
              ],
            ),
            const SizedBox(height: 8),
            // Details
            Text(
              event.details,
              style: AppTextStyles.sans(size: 11, color: Palantir.textMuted),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Bottom: timestamp, source, link
            Row(
              children: [
                Text(
                  formatTimestamp(event.timestamp),
                  style: AppTextStyles.mono(
                    size: 10,
                    color: Palantir.textMuted,
                  ),
                ),
                const Spacer(),
                if (event.source != null) ...[
                  Text(
                    event.source!,
                    style: AppTextStyles.mono(
                      size: 10,
                      weight: FontWeight.w600,
                      color: Palantir.accent,
                    ),
                  ),
                ],
                if (event.sourceUrl != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _openUrl(event.sourceUrl!),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_new,
                          size: 10,
                          color: Palantir.info,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'SOURCE',
                          style: AppTextStyles.mono(
                            size: 11,
                            weight: FontWeight.w600,
                            color: Palantir.info,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (event.status == EventStatus.ongoing) ...[
                  const SizedBox(width: 8),
                  const PulsingDot(color: Palantir.warning, size: 5),
                ],
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _attackTypeIcon(AttackType type) {
    final IconData icon;
    final Color color = _attackTypeColor(type);

    switch (type) {
      case AttackType.ballistic:
        icon = Icons.rocket_launch;
      case AttackType.cruise:
        icon = Icons.flight;
      case AttackType.drone:
        icon = Icons.air;
      case AttackType.artillery:
        icon = Icons.gps_fixed;
      case AttackType.cyber:
        icon = Icons.memory;
      case AttackType.sabotage:
        icon = Icons.warning_amber;
      case AttackType.general:
        icon = Icons.info_outline;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }

  Color _attackTypeColor(AttackType type) {
    switch (type) {
      case AttackType.ballistic:
        return AttackColors.ballistic;
      case AttackType.cruise:
        return AttackColors.cruise;
      case AttackType.drone:
        return AttackColors.drone;
      case AttackType.artillery:
        return AttackColors.artillery;
      case AttackType.cyber:
        return AttackColors.cyber;
      case AttackType.sabotage:
        return AttackColors.sabotage;
      case AttackType.general:
        return AttackColors.general;
    }
  }

  String _attackTypeLabel(AttackType type) {
    switch (type) {
      case AttackType.ballistic:
        return 'BALLISTIC MISSILE';
      case AttackType.cruise:
        return 'CRUISE MISSILE';
      case AttackType.drone:
        return 'UAS / DRONE';
      case AttackType.artillery:
        return 'ARTILLERY / ROCKET';
      case AttackType.cyber:
        return 'CYBER OPERATION';
      case AttackType.sabotage:
        return 'SABOTAGE / SOF';
      case AttackType.general:
        return 'MILITARY EVENT';
    }
  }

  // ── OSINT TAB ────────────────────────────────────────────────────

  String _osintCountryFromRegion(String region) {
    final upper = region.toUpperCase();
    if (upper.contains('UAE') || upper.contains('DUBAI') || upper.contains('ABU DHABI') || upper.contains('EMIRATES')) return 'UAE';
    if (upper.contains('ISRAEL') || upper.contains('TEL AVIV') || upper.contains('JERUSALEM')) return 'ISRAEL';
    if (upper.contains('IRAN') || upper.contains('TEHRAN') || upper.contains('ISFAHAN')) return 'IRAN';
    if (upper.contains('SAUDI') || upper.contains('KSA') || upper.contains('RIYADH')) return 'KSA';
    if (upper.contains('KUWAIT')) return 'KUWAIT';
    if (upper.contains('BAHRAIN') || upper.contains('MANAMA')) return 'BAHRAIN';
    if (upper.contains('QATAR') || upper.contains('DOHA')) return 'QATAR';
    if (upper.contains('OMAN') || upper.contains('MUSCAT')) return 'OMAN';
    if (upper.contains('JORDAN') || upper.contains('AMMAN')) return 'JORDAN';
    if (upper.contains('LEBANON') || upper.contains('BEIRUT')) return 'LEBANON';
    if (upper.contains('IRAQ') || upper.contains('BAGHDAD')) return 'IRAQ';
    if (upper.contains('SYRIA') || upper.contains('DAMASCUS')) return 'SYRIA';
    if (upper.contains('YEMEN') || upper.contains('HOUTHI') || upper.contains('SANAA')) return 'YEMEN';
    if (upper.contains('USA') || upper.contains('CENTCOM') || upper.contains('PENTAGON')) return 'USA';
    if (upper.contains('UK') || upper.contains('BRITAIN')) return 'UK';
    if (upper.contains('FRANCE') || upper.contains('FRENCH')) return 'FRANCE';
    return 'OTHER';
  }

  String _osintPriorityLabel(OsintPriority p) {
    switch (p) {
      case OsintPriority.flash: return 'FLASH';
      case OsintPriority.immediate: return 'IMMEDIATE';
      case OsintPriority.priority: return 'PRIORITY';
      case OsintPriority.routine: return 'ROUTINE';
    }
  }

  String _osintSourceCategory(OsintSource source) {
    switch (source) {
      case OsintSource.centcom:
      case OsintSource.dod:
      case OsintSource.idf:
        return 'MILITARY';
      case OsintSource.reuters:
      case OsintSource.ap:
      case OsintSource.bloomberg:
        return 'WIRE';
      case OsintSource.aljazeera:
        return 'NEWS';
      case OsintSource.flightradar:
        return 'TRACKING';
      case OsintSource.wam:
      case OsintSource.spa:
      case OsintSource.qna:
      case OsintSource.bna:
      case OsintSource.kuna:
      case OsintSource.omanNews:
        return 'GOV';
      default:
        return 'PRESS';
    }
  }

  List<OsintItem> _filteredOsint(List<OsintItem> items) {
    var result = items;
    if (_osintCountryFilter.isNotEmpty) {
      result = result.where((i) => _osintCountryFilter.contains(_osintCountryFromRegion(i.region))).toList();
    }
    if (_osintPriorityFilter.isNotEmpty) {
      result = result.where((i) => _osintPriorityFilter.contains(_osintPriorityLabel(i.priority))).toList();
    }
    if (_osintSourceFilter.isNotEmpty) {
      result = result.where((i) => _osintSourceFilter.contains(_osintSourceCategory(i.source))).toList();
    }
    return result;
  }

  Widget _buildOsintTab() {
    final osintItems = ref.watch(osintProvider);
    final filtered = _filteredOsint(osintItems);

    return Column(
      children: [
        const SizedBox(height: 8),
        // Country filter
        FilterChipRow(
          labels: const ['UAE', 'KSA', 'KUWAIT', 'BAHRAIN', 'QATAR', 'OMAN', 'JORDAN', 'ISRAEL', 'IRAN', 'LEBANON', 'IRAQ', 'SYRIA', 'YEMEN', 'USA', 'UK', 'FRANCE'],
          selected: _osintCountryFilter,
          onToggle: (label) => setState(() {
            _osintCountryFilter.contains(label) ? _osintCountryFilter.remove(label) : _osintCountryFilter.add(label);
          }),
          activeColor: Palantir.accent,
        ),
        const SizedBox(height: 4),
        // Priority filter
        FilterChipRow(
          labels: const ['FLASH', 'IMMEDIATE', 'PRIORITY', 'ROUTINE'],
          selected: _osintPriorityFilter,
          onToggle: (label) => setState(() {
            _osintPriorityFilter.contains(label) ? _osintPriorityFilter.remove(label) : _osintPriorityFilter.add(label);
          }),
          activeColor: Palantir.danger,
        ),
        const SizedBox(height: 4),
        // Source category filter
        FilterChipRow(
          labels: const ['MILITARY', 'GOV', 'WIRE', 'NEWS', 'PRESS', 'TRACKING'],
          selected: _osintSourceFilter,
          onToggle: (label) => setState(() {
            _osintSourceFilter.contains(label) ? _osintSourceFilter.remove(label) : _osintSourceFilter.add(label);
          }),
          activeColor: Palantir.info,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            color: Palantir.accent,
            backgroundColor: Palantir.surface,
            onRefresh: () => ref.read(osintProvider.notifier).refresh(),
            child: filtered.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.rss_feed, size: 32, color: Palantir.textMuted),
                            const SizedBox(height: 12),
                            Text(
                              osintItems.isEmpty ? 'WAITING FOR OSINT DATA...' : 'NO ITEMS MATCH FILTERS',
                              style: AppTextStyles.mono(size: 10, color: Palantir.textMuted, letterSpacing: 1.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              osintItems.isEmpty ? 'Pull to refresh' : 'Adjust filters above',
                              style: AppTextStyles.sans(size: 11, color: Palantir.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                final hasUrl = item.url != null && item.url!.isNotEmpty;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: hasUrl ? () => _openUrl(item.url!) : null,
                    child: PalantirCard(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _osintSourceBadge(item.source),
                            const Spacer(),
                            Text(
                              formatTimestamp(item.timestamp),
                              style: AppTextStyles.mono(
                                size: 10,
                                color: Palantir.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            PriorityBadge(priority: item.priority),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.title,
                          style: AppTextStyles.sans(
                            size: 13,
                            weight: FontWeight.w600,
                            color: Palantir.text,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.summary,
                          style: AppTextStyles.sans(
                            size: 11,
                            color: Palantir.textMuted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.public, size: 10, color: Palantir.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              item.region,
                              style: AppTextStyles.mono(
                                size: 10,
                                color: Palantir.textMuted,
                              ),
                            ),
                            if (hasUrl) ...[
                              const Spacer(),
                              Icon(Icons.open_in_new, size: 10, color: Palantir.info),
                              const SizedBox(width: 2),
                              Text(
                                'SOURCE',
                                style: AppTextStyles.mono(
                                  size: 10,
                                  weight: FontWeight.w600,
                                  color: Palantir.info,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _osintSourceBadge(OsintSource source) {
    final String label;
    final Color color;
    switch (source) {
      case OsintSource.reuters:
        label = 'REUTERS';
        color = Palantir.orange;
      case OsintSource.aljazeera:
        label = 'AL JAZEERA';
        color = Palantir.success;
      case OsintSource.dod:
        label = 'DoD';
        color = Palantir.purple;
      case OsintSource.idf:
        label = 'IDF';
        color = Palantir.cyan;
      case OsintSource.ap:
        label = 'AP';
        color = Palantir.warning;
      case OsintSource.centcom:
        label = 'CENTCOM';
        color = Palantir.info;
      case OsintSource.flightradar:
        label = 'FR24';
        color = Palantir.textMuted;
      default:
        final cfg = sourceConfig[source];
        label = cfg?.label ?? source.name.toUpperCase();
        color = Color(cfg?.colorValue ?? 0xFF9CA3AF);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: AppTextStyles.mono(
          size: 11,
          weight: FontWeight.w700,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ── CENTCOM TAB ────────────────────────────────────────────────────

  List<CentcomBriefing> _filteredCentcom(List<CentcomBriefing> all) {
    if (_centcomCategoryFilter.isEmpty) return all;
    return all.where((item) {
      switch (item.category) {
        case CentcomCategory.pressRelease:
          return _centcomCategoryFilter.contains('PRESS');
        case CentcomCategory.news:
          return _centcomCategoryFilter.contains('NEWS');
        case CentcomCategory.statement:
          return _centcomCategoryFilter.contains('STATEMENT');
      }
    }).toList();
  }

  Widget _buildCentcomTab() {
    final centcomState = ref.watch(centcomProvider);
    final filtered = _filteredCentcom(centcomState.briefings);

    return Column(
      children: [
        const SizedBox(height: 8),
        // Stats row
        _buildCentcomStats(centcomState.briefings),
        const SizedBox(height: 8),
        // Category filter chips
        FilterChipRow(
          labels: const ['PRESS', 'NEWS', 'STATEMENT'],
          selected: _centcomCategoryFilter,
          onToggle: (label) {
            setState(() {
              _centcomCategoryFilter.contains(label)
                  ? _centcomCategoryFilter.remove(label)
                  : _centcomCategoryFilter.add(label);
            });
          },
          activeColor: Palantir.info,
        ),
        const SizedBox(height: 8),
        // Briefing list
        Expanded(
          child: RefreshIndicator(
            color: Palantir.accent,
            backgroundColor: Palantir.surface,
            onRefresh: () => ref.read(centcomProvider.notifier).refresh(),
            child: centcomState.isLoading && centcomState.briefings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Palantir.info,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'FETCHING CENTCOM BRIEFINGS...',
                          style: AppTextStyles.mono(
                            size: 11,
                            color: Palantir.textMuted,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  )
                : filtered.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Column(
                              children: [
                                Icon(Icons.military_tech, size: 32, color: Palantir.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  centcomState.error != null
                                      ? 'BACKEND OFFLINE'
                                      : 'NO BRIEFINGS AVAILABLE',
                                  style: AppTextStyles.mono(
                                    size: 10,
                                    color: Palantir.textMuted,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Pull to refresh',
                                  style: AppTextStyles.sans(
                                    size: 11,
                                    color: Palantir.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildCentcomCard(filtered[index]);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildCentcomStats(List<CentcomBriefing> items) {
    final pressCount = items.where((i) => i.category == CentcomCategory.pressRelease).length;
    final newsCount = items.where((i) => i.category == CentcomCategory.news).length;
    final stmtCount = items.where((i) => i.category == CentcomCategory.statement).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statPill('PRESS', pressCount, Palantir.info),
          const SizedBox(width: 8),
          _statPill('NEWS', newsCount, Palantir.cyan),
          const SizedBox(width: 8),
          _statPill('STMT', stmtCount, Palantir.purple),
          const Spacer(),
          Text(
            '${items.length} ITEMS',
            style: AppTextStyles.mono(
              size: 10,
              color: Palantir.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 6),
          const PulsingDot(color: Palantir.info, size: 5),
        ],
      ),
    );
  }

  Widget _statPill(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.mono(
              size: 11,
              weight: FontWeight.w600,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: AppTextStyles.mono(
              size: 11,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCentcomCard(CentcomBriefing item) {
    final hasLink = item.link.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PalantirCard(
        borderColor: item.priority == CentcomPriority.flash
            ? Palantir.danger.withValues(alpha: 0.5)
            : null,
        onTap: hasLink ? () => _openUrl(item.link) : null,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: category badge, timestamp, priority
            Row(
              children: [
                _centcomCategoryBadge(item.category),
                const Spacer(),
                Text(
                  formatTimestamp(item.timestamp),
                  style: AppTextStyles.mono(
                    size: 10,
                    color: Palantir.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                _centcomPriorityBadge(item.priority),
              ],
            ),
            const SizedBox(height: 6),
            // Title
            Text(
              item.title,
              style: AppTextStyles.sans(
                size: 13,
                weight: FontWeight.w600,
                color: hasLink ? Palantir.text : Palantir.textMuted,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              // Summary
              Text(
                item.summary,
                style: AppTextStyles.sans(
                  size: 11,
                  color: Palantir.textMuted,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            // Bottom: flash dot + clickable FULL BRIEF button
            Row(
              children: [
                if (item.priority == CentcomPriority.flash) ...[
                  const PulsingDot(color: Palantir.danger, size: 5),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                if (hasLink)
                  GestureDetector(
                    onTap: () => _openUrl(item.link),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Palantir.info.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Palantir.info.withValues(alpha: 0.4),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_in_new,
                            size: 10,
                            color: Palantir.info,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'FULL BRIEF',
                            style: AppTextStyles.mono(
                              size: 10,
                              weight: FontWeight.w700,
                              color: Palantir.info,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _centcomCategoryBadge(CentcomCategory category) {
    final String label;
    final Color color;
    switch (category) {
      case CentcomCategory.pressRelease:
        label = 'PRESS RELEASE';
        color = Palantir.info;
      case CentcomCategory.news:
        label = 'NEWS';
        color = Palantir.cyan;
      case CentcomCategory.statement:
        label = 'STATEMENT';
        color = Palantir.purple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: AppTextStyles.mono(
          size: 11,
          weight: FontWeight.w700,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _centcomPriorityBadge(CentcomPriority priority) {
    final String label;
    final Color color;
    switch (priority) {
      case CentcomPriority.flash:
        label = 'FLASH';
        color = Palantir.danger;
      case CentcomPriority.immediate:
        label = 'IMMEDIATE';
        color = Palantir.orange;
      case CentcomPriority.priority:
        label = 'PRIORITY';
        color = Palantir.warning;
      case CentcomPriority.routine:
        label = 'ROUTINE';
        color = Palantir.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: AppTextStyles.mono(
          size: 11,
          weight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // ── LIVE TV TAB ──────────────────────────────────────────────────

  Widget _buildLiveTvTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Disclaimer ──
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Palantir.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Palantir.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: Palantir.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'During crises, some streams may be unavailable.',
                    style: AppTextStyles.mono(size: 10, color: Palantir.warning),
                  ),
                ),
              ],
            ),
          ),
          // ── INTERNATIONAL ──
          _sectionHeader('INTERNATIONAL'),
          _tvChannelCard(
            'Al Jazeera English',
            'LIVE 24/7',
            Palantir.success,
            'https://www.aljazeera.com/live/',
            youtubeUrl: 'https://www.youtube.com/@aljazeeraenglish',
          ),
          _tvChannelCard(
            'BBC World News',
            'LIVE',
            Palantir.info,
            'https://www.bbc.com/news/live',
            youtubeUrl: 'https://www.youtube.com/@BBCNews',
          ),
          _tvChannelCard(
            'CNN International',
            'LIVE',
            Palantir.danger,
            'https://edition.cnn.com/live-tv',
            youtubeUrl: 'https://www.youtube.com/@CNN',
          ),
          _tvChannelCard(
            'Sky News',
            'LIVE',
            Palantir.warning,
            'https://news.sky.com/watch-live',
            youtubeUrl: 'https://www.youtube.com/@SkyNews',
          ),

          // ── USA 🇺🇸 ──
          const SizedBox(height: 12),
          _sectionHeader('\u{1F1FA}\u{1F1F8} UNITED STATES'),
          _tvChannelCard(
            'Fox News',
            'LIVE',
            Palantir.danger,
            'https://www.foxnews.com/video/5614615980001',
            youtubeUrl: 'https://www.youtube.com/@FoxNews',
          ),
          _tvChannelCard(
            'ABC News',
            'LIVE',
            Palantir.info,
            'https://abcnews.go.com/live',
            youtubeUrl: 'https://www.youtube.com/@ABCNews',
          ),
          _tvChannelCard(
            'NBC News',
            'LIVE',
            Palantir.purple,
            'https://www.nbcnews.com/now',
            youtubeUrl: 'https://www.youtube.com/@NBCNews',
          ),
          _tvChannelCard(
            'CBS News',
            'LIVE 24/7',
            Palantir.cyan,
            'https://www.cbsnews.com/live/',
            youtubeUrl: 'https://www.youtube.com/@CBSNews',
          ),
          _tvChannelCard(
            'C-SPAN',
            'LIVE',
            Palantir.textMuted,
            'https://www.c-span.org/networks/',
            youtubeUrl: 'https://www.youtube.com/@CSPAN',
          ),

          // ── ISRAEL 🇮🇱 ──
          const SizedBox(height: 12),
          _sectionHeader('\u{1F1EE}\u{1F1F1} ISRAEL'),
          _tvChannelCard(
            'i24NEWS English',
            'LIVE 24/7',
            Palantir.info,
            'https://www.i24news.tv/en/live',
            youtubeUrl: 'https://www.youtube.com/@i24NEWSEnglish',
          ),
          _tvChannelCard(
            'Kan News',
            'LIVE',
            Palantir.cyan,
            'https://www.kan.org.il/live/',
            youtubeUrl: 'https://www.youtube.com/@kann11',
          ),
          _tvChannelCard(
            'The Times of Israel',
            'LIVE',
            Palantir.info,
            'https://www.timesofisrael.com/liveblog/',
          ),
          _tvChannelCard(
            'Ynet News (Yedioth)',
            'NEWS',
            Palantir.warning,
            'https://www.ynetnews.com/',
          ),
          _tvChannelCard(
            'Haaretz',
            'NEWS',
            Palantir.success,
            'https://www.haaretz.com/',
          ),
          _tvChannelCard(
            'Jerusalem Post',
            'NEWS',
            Palantir.purple,
            'https://www.jpost.com/',
          ),

          // ── UK 🇬🇧 ──
          const SizedBox(height: 12),
          _sectionHeader('\u{1F1EC}\u{1F1E7} UNITED KINGDOM'),
          _tvChannelCard(
            'GB News',
            'LIVE',
            Palantir.accent,
            'https://www.gbnews.com/watch/live',
            youtubeUrl: 'https://www.youtube.com/@GBNewsOnline',
          ),
          _tvChannelCard(
            'The Guardian',
            'NEWS',
            Palantir.info,
            'https://www.theguardian.com/world',
          ),

          // ── FRANCE 🇫🇷 ──
          const SizedBox(height: 12),
          _sectionHeader('\u{1F1EB}\u{1F1F7} FRANCE'),
          _tvChannelCard(
            'France 24 English',
            'LIVE 24/7',
            Palantir.cyan,
            'https://www.france24.com/en/live',
            youtubeUrl: 'https://www.youtube.com/@FRANCE24English',
          ),
          _tvChannelCard(
            'BFM TV',
            'LIVE',
            Palantir.info,
            'https://www.bfmtv.com/en-direct/',
            youtubeUrl: 'https://www.youtube.com/@BFMTV',
          ),

          // ── GERMANY 🇩🇪 ──
          const SizedBox(height: 12),
          _sectionHeader('\u{1F1E9}\u{1F1EA} GERMANY'),
          _tvChannelCard(
            'DW News',
            'LIVE 24/7',
            Palantir.info,
            'https://www.dw.com/en/live-tv/s-100825',
            youtubeUrl: 'https://www.youtube.com/@DWNews',
          ),

          // ── UAE 🇦🇪 ──
          const SizedBox(height: 12),
          _sectionHeader('\u{1F1E6}\u{1F1EA} UAE'),
          _tvChannelCard(
            'Al Arabiya',
            'LIVE',
            Palantir.orange,
            'https://www.alarabiya.net/live',
            youtubeUrl: 'https://www.youtube.com/@AlArabiya',
          ),
          _tvChannelCard(
            'The National (UAE)',
            'NEWS',
            Palantir.cyan,
            'https://www.thenationalnews.com/',
          ),
          _tvChannelCard(
            'Gulf News',
            'NEWS',
            Palantir.info,
            'https://gulfnews.com/',
          ),

          // ── KSA 🇸🇦 ──
          const SizedBox(height: 12),
          _sectionHeader('\u{1F1F8}\u{1F1E6} SAUDI ARABIA'),
          _tvChannelCard(
            'Al Ekhbariya',
            'LIVE',
            Palantir.success,
            'https://www.alekhbariya.net/',
            youtubeUrl: 'https://www.youtube.com/@AlEkhbariya',
          ),
          _tvChannelCard(
            'Arab News',
            'NEWS',
            Palantir.info,
            'https://www.arabnews.com/',
          ),

          // ── QATAR 🇶🇦 ──
          const SizedBox(height: 12),
          _sectionHeader('\u{1F1F6}\u{1F1E6} QATAR'),
          _tvChannelCard(
            'Al Jazeera Arabic',
            'LIVE 24/7',
            Palantir.success,
            'https://www.aljazeera.net/live/',
            youtubeUrl: 'https://www.youtube.com/@aljazeera',
          ),

          // ── BAHRAIN 🇧🇭 ──
          const SizedBox(height: 12),
          _sectionHeader('\u{1F1E7}\u{1F1ED} BAHRAIN'),
          _tvChannelCard(
            'Bahrain News Agency',
            'NEWS',
            Palantir.info,
            'https://www.bna.bh/en/',
          ),

          // ── IRAN 🇮🇷 (Axis monitoring) ──
          const SizedBox(height: 12),
          _sectionHeader('\u{1F1EE}\u{1F1F7} IRAN (AXIS MONITORING)'),
          _tvChannelCard(
            'Press TV',
            'LIVE',
            Palantir.danger,
            'https://www.presstv.ir/live',
            youtubeUrl: 'https://www.youtube.com/@PressTVEnglish',
          ),
          _tvChannelCard(
            'IRNA (Islamic Republic News)',
            'NEWS',
            Palantir.danger,
            'https://en.irna.ir/',
          ),
          _tvChannelCard(
            'Tehran Times',
            'NEWS',
            Palantir.warning,
            'https://www.tehrantimes.com/',
          ),

          // ── LEBANON 🇱🇧 ──
          const SizedBox(height: 12),
          _sectionHeader('\u{1F1F1}\u{1F1E7} LEBANON'),
          _tvChannelCard(
            'Al Manar (Hezbollah)',
            'LIVE',
            Palantir.danger,
            'https://www.almanar.com.lb/live',
          ),
          _tvChannelCard(
            'L\'Orient Today',
            'NEWS',
            Palantir.cyan,
            'https://today.lorientlejour.com/',
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'STREAMS OPEN IN EXTERNAL BROWSER',
              style: AppTextStyles.mono(
                size: 10,
                color: Palantir.textMuted,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.mono(
                size: 11,
                weight: FontWeight.w700,
                color: Palantir.accent,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.5,
              color: Palantir.border,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tvChannelCard(
    String name,
    String status,
    Color color,
    String url, {
    String? youtubeUrl,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PalantirCard(
        onTap: () => _openUrl(url),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.live_tv, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: Palantir.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Palantir.danger,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status,
                        style: AppTextStyles.mono(
                          size: 10,
                          weight: FontWeight.w700,
                          color: Palantir.danger,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (youtubeUrl != null)
              GestureDetector(
                onTap: () => _openUrl(youtubeUrl),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Palantir.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Palantir.danger.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 14,
                    color: Palantir.danger,
                  ),
                ),
              ),
            GestureDetector(
              onTap: () => _openUrl(url),
              child: Icon(Icons.open_in_new, size: 14, color: Palantir.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ── TOOLS TAB ────────────────────────────────────────────────────

  Widget _buildToolsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('OSINT TOOLS', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 4),
          Text(
            'Quick access to open-source intelligence platforms',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),
          _toolCard(
            'FlightRadar24',
            'Live aircraft tracking worldwide',
            Icons.flight_takeoff,
            Palantir.cyan,
            'https://flightradar24.com',
          ),
          _toolCard(
            'MarineTraffic',
            'Real-time ship tracking and AIS data',
            Icons.directions_boat,
            Palantir.info,
            'https://marinetraffic.com',
          ),
          _toolCard(
            'Liveuamap',
            'Live conflict and crisis map',
            Icons.map,
            Palantir.danger,
            'https://liveuamap.com',
          ),
          _toolCard(
            'FIRMS (NASA)',
            'Active fire / explosion detection',
            Icons.local_fire_department,
            Palantir.orange,
            'https://firms.modaps.eosdis.nasa.gov',
          ),
          _toolCard(
            'ADS-B Exchange',
            'Unfiltered ADS-B aircraft data',
            Icons.radar,
            Palantir.success,
            'https://globe.adsbexchange.com',
          ),
          _toolCard(
            'Sentinel Hub',
            'Satellite imagery analysis',
            Icons.satellite_alt,
            Palantir.purple,
            'https://apps.sentinel-hub.com',
          ),
        ],
      ),
    );
  }

  Widget _toolCard(
    String name,
    String desc,
    IconData icon,
    Color color,
    String url,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PalantirCard(
        onTap: () => _openUrl(url),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: Palantir.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: AppTextStyles.sans(
                      size: 10,
                      color: Palantir.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 14, color: Palantir.textMuted),
          ],
        ),
      ),
    );
  }
}
