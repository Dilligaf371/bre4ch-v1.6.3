// =============================================================================
// BRE4CH - Delta-S Screen
// WATCHDOG-IRAN AI Briefing + OSINT + SOCMINT intelligence feeds
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../models/osint_item.dart';
import '../providers/briefing_provider.dart';
import '../providers/osint_provider.dart';
import '../utils/formatters.dart';
import '../widgets/common/header_bar.dart';
import '../widgets/common/palantir_card.dart';
import '../widgets/common/pulsing_dot.dart';

class DeltaSScreen extends ConsumerStatefulWidget {
  const DeltaSScreen({super.key});

  @override
  ConsumerState<DeltaSScreen> createState() => _DeltaSScreenState();
}

class _DeltaSScreenState extends ConsumerState<DeltaSScreen> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now().toUtc();

  static final DateTime _opStart = DateTime.now().toUtc().subtract(const Duration(days: 4, hours: 3, minutes: 31));

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palantir.bg,
      body: SafeArea(
        child: Column(
          children: [
            const HeaderBar(),
            Expanded(child: _buildBriefingTab()),
          ],
        ),
      ),
    );
  }

  // ── BRIEFING TAB — WATCHDOG-IRAN AI BRIEFING ─────────────────────

  Widget _buildBriefingTab() {
    final briefingState = ref.watch(briefingProvider);
    final osintItems = ref.watch(osintProvider);

    final elapsed = _now.difference(_opStart);
    final zuluFmt = DateFormat('EEE, dd MMM yyyy HH:mm:ss');

    final wdc = _now.subtract(const Duration(hours: 5));
    final dxb = _now.add(const Duration(hours: 4));
    final thr = _now.add(const Duration(hours: 3, minutes: 30));

    return RefreshIndicator(
      color: Palantir.accent,
      backgroundColor: Palantir.surface,
      onRefresh: () async {
        await ref.read(briefingProvider.notifier).refresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── WATCHDOG Header ──
            _buildWatchdogHeader(briefingState, zuluFmt, elapsed, wdc, dxb, thr),
            const SizedBox(height: 12),

            // ── Briefing Content ──
            if (briefingState.hasBriefing)
              _buildBriefingContent(briefingState.content!)
            else if (briefingState.isLoading)
              _buildLoadingPlaceholder()
            else
              _buildNoBriefingPlaceholder(briefingState),

            const SizedBox(height: 16),

            // ── OSINT Headlines ──
            Row(
              children: [
                Icon(Icons.rss_feed, size: 14, color: Palantir.text),
                const SizedBox(width: 6),
                Text('LATEST FROM SOURCES', style: AppTextStyles.mono(size: 12, weight: FontWeight.w700, color: Palantir.text, letterSpacing: 1.5)),
                const Spacer(),
                Text('${osintItems.length} ITEMS', style: AppTextStyles.mono(size: 10, color: Palantir.textMuted)),
              ],
            ),
            const SizedBox(height: 8),
            if (osintItems.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No source headlines available', style: AppTextStyles.sans(size: 11, color: Palantir.textMuted)),
              )
            else
              ...osintItems.take(8).map((item) => _buildLiveSourceItem(item)),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── WATCHDOG Header Card ──────────────────────────────────────────

  Widget _buildWatchdogHeader(
    BriefingState bs, DateFormat zuluFmt, Duration elapsed,
    DateTime wdc, DateTime dxb, DateTime thr,
  ) {
    final cooldownColor = bs.cooldown == Duration.zero ? Palantir.accent : Palantir.cyan;

    return PalantirCard(
      borderColor: Palantir.danger.withValues(alpha: 0.5),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Palantir.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Palantir.danger)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('BRE4CH BRIEFING', style: AppTextStyles.mono(size: 14, weight: FontWeight.w800, color: Palantir.text, letterSpacing: 1.0)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cooldownColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: cooldownColor.withValues(alpha: 0.4), width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule, size: 10, color: cooldownColor),
                      const SizedBox(width: 4),
                      Text('NEXT ${bs.cooldownText}', style: AppTextStyles.mono(size: 9, weight: FontWeight.w700, color: cooldownColor, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Classification + badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Palantir.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(3)),
                      child: Text('WATCHDOG-IRAN', style: AppTextStyles.mono(size: 9, weight: FontWeight.w800, color: Palantir.danger, letterSpacing: 1.0)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Palantir.border, borderRadius: BorderRadius.circular(3)),
                      child: Text('UNCLASSIFIED // FOUO', style: AppTextStyles.mono(size: 8, weight: FontWeight.w600, color: Palantir.textMuted, letterSpacing: 0.5)),
                    ),
                    const Spacer(),
                    if (bs.isLoading)
                      SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Palantir.accent))
                    else if (bs.hasBriefing)
                      const PulsingDot(color: Palantir.success, size: 6),
                  ],
                ),
                const SizedBox(height: 8),

                // Operation banner
                Text(
                  'OP EPIC FURY // IRAN THEATRE${bs.dayN != null ? ' // J+${bs.dayN}' : ''}',
                  style: AppTextStyles.mono(size: 11, weight: FontWeight.w700, color: Palantir.accent, letterSpacing: 1.2),
                ),
                const SizedBox(height: 6),

                // Zulu time
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Palantir.textMuted),
                    const SizedBox(width: 4),
                    Text('${zuluFmt.format(_now)} Z', style: AppTextStyles.mono(size: 11, color: Palantir.textMuted)),
                  ],
                ),
                const SizedBox(height: 4),

                // World clocks
                Text(
                  'Elapsed: ${_fmtElapsed(elapsed)} | WDC ${_fmtClock(wdc)} | DXB ${_fmtClock(dxb)} | THR ${_fmtClock(thr)}',
                  style: AppTextStyles.mono(size: 10, color: Palantir.textMuted),
                ),

                // Generation info
                if (bs.generatedAt != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 11, color: Palantir.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Generated ${DateFormat('dd MMM yyyy HH:mm').format(bs.generatedAt!)}Z',
                        style: AppTextStyles.mono(size: 10, weight: FontWeight.w600, color: Palantir.accent),
                      ),
                      if (bs.groundingSources != null && bs.groundingSources! > 0) ...[
                        const SizedBox(width: 8),
                        Text('${bs.groundingSources} web sources', style: AppTextStyles.mono(size: 10, color: Palantir.textMuted)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Briefing Markdown Content — Collapsible Sections ─────────────

  /// Parse briefing into sections split by `## ` headers.
  /// Returns list of (title, body) pairs.
  List<(String, String)> _parseSections(String content) {
    final sections = <(String, String)>[];
    final lines = content.split('\n');
    String? currentTitle;
    final buffer = StringBuffer();

    for (final line in lines) {
      if (line.startsWith('## ')) {
        // Save previous section
        if (currentTitle != null) {
          sections.add((currentTitle, buffer.toString().trim()));
        } else if (buffer.isNotEmpty) {
          // Content before first ## (title block)
          sections.add(('_header', buffer.toString().trim()));
        }
        currentTitle = line.substring(3).trim();
        buffer.clear();
      } else {
        buffer.writeln(line);
      }
    }
    // Save last section
    if (currentTitle != null) {
      sections.add((currentTitle, buffer.toString().trim()));
    } else if (buffer.isNotEmpty) {
      sections.add(('_header', buffer.toString().trim()));
    }
    return sections;
  }

  /// Section icon based on title keyword
  IconData _sectionIcon(String title) {
    final t = title.toUpperCase();
    if (t.contains('EXECUTIVE') || t.contains('SUMMARY')) return Icons.summarize;
    if (t.contains('THREAT')) return Icons.warning_amber;
    if (t.contains('EVENT')) return Icons.event_note;
    if (t.contains('BATTLEFIELD') || t.contains('STATUS')) return Icons.military_tech;
    if (t.contains('RESIDUAL') || t.contains('CAPABILITIES')) return Icons.shield;
    if (t.contains('REGIONAL')) return Icons.public;
    if (t.contains('POLITICAL') || t.contains('DIPLOMATIC')) return Icons.account_balance;
    if (t.contains('ECONOMIC')) return Icons.trending_up;
    if (t.contains('OUTLOOK')) return Icons.visibility;
    if (t.contains('SOURCE')) return Icons.link;
    return Icons.article;
  }

  /// Section accent color
  Color _sectionColor(String title) {
    final t = title.toUpperCase();
    if (t.contains('THREAT')) return Palantir.danger;
    if (t.contains('EVENT')) return Palantir.orange;
    if (t.contains('BATTLEFIELD') || t.contains('STATUS')) return Palantir.cyan;
    if (t.contains('RESIDUAL') || t.contains('CAPABILITIES')) return Palantir.warning;
    if (t.contains('OUTLOOK')) return Palantir.success;
    return Palantir.accent;
  }

  MarkdownStyleSheet get _mdStyle => MarkdownStyleSheet(
    h1: AppTextStyles.mono(size: 16, weight: FontWeight.w800, color: Palantir.accent, letterSpacing: 1.0),
    h2: AppTextStyles.mono(size: 14, weight: FontWeight.w700, color: Palantir.text, letterSpacing: 1.0),
    h3: AppTextStyles.mono(size: 12, weight: FontWeight.w600, color: Palantir.cyan),
    h4: AppTextStyles.mono(size: 11, weight: FontWeight.w600, color: Palantir.textMuted),
    p: AppTextStyles.sans(size: 12, color: Palantir.text),
    strong: AppTextStyles.sans(size: 12, weight: FontWeight.w700, color: Palantir.text),
    em: AppTextStyles.sans(size: 12, color: Palantir.textMuted),
    a: AppTextStyles.mono(size: 11, color: Palantir.cyan),
    code: AppTextStyles.mono(size: 11, color: Palantir.accent),
    codeblockDecoration: BoxDecoration(
      color: Palantir.bg,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Palantir.border),
    ),
    codeblockPadding: const EdgeInsets.all(12),
    tableHead: AppTextStyles.mono(size: 10, weight: FontWeight.w700, color: Palantir.accent, letterSpacing: 0.5),
    tableBody: AppTextStyles.mono(size: 10, color: Palantir.text),
    tableBorder: TableBorder.all(color: Palantir.border, width: 0.5),
    tableHeadAlign: TextAlign.left,
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    listBullet: AppTextStyles.sans(size: 12, color: Palantir.accent),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: Palantir.border, width: 1)),
    ),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: Palantir.accent, width: 3)),
    ),
    blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
    blockquote: AppTextStyles.sans(size: 11, color: Palantir.textMuted),
  );

  Widget _buildBriefingContent(String content) {
    final sections = _parseSections(content);

    return Column(
      children: sections.map((section) {
        final (title, body) = section;

        // Header block (before first ##) — always visible, no card
        if (title == '_header') {
          return const SizedBox.shrink();
        }

        final isExecSummary = title.toUpperCase().contains('EXECUTIVE SUMMARY');
        final color = _sectionColor(title);
        final icon = _sectionIcon(title);

        // Executive Summary — always expanded, no collapse
        if (isExecSummary) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PalantirCard(
              borderColor: Palantir.accent.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 14, color: Palantir.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title.toUpperCase(),
                          style: AppTextStyles.mono(size: 11, weight: FontWeight.w800, color: Palantir.accent, letterSpacing: 1.2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MarkdownBody(
                    data: body,
                    selectable: true,
                    onTapLink: (text, href, t2) { if (href != null) _openUrl(href); },
                    styleSheet: _mdStyle,
                  ),
                ],
              ),
            ),
          );
        }

        // All other sections — collapsible tile
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                color: Palantir.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Palantir.border.withValues(alpha: 0.5), width: 0.5),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  initiallyExpanded: false,
                  collapsedIconColor: Palantir.textMuted,
                  iconColor: color,
                  leading: Icon(icon, size: 14, color: color),
                  title: Text(
                    title.toUpperCase(),
                    style: AppTextStyles.mono(size: 10, weight: FontWeight.w700, color: Palantir.text, letterSpacing: 1.0),
                  ),
                  children: [
                    MarkdownBody(
                      data: body,
                      selectable: true,
                      shrinkWrap: true,
                      onTapLink: (text, href, t2) { if (href != null) _openUrl(href); },
                      styleSheet: _mdStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Placeholder States ────────────────────────────────────────────

  Widget _buildLoadingPlaceholder() {
    return PalantirCard(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Palantir.accent)),
            const SizedBox(height: 16),
            Text('Generating intelligence briefing...', style: AppTextStyles.sans(size: 12, color: Palantir.textMuted)),
            const SizedBox(height: 4),
            Text('WATCHDOG-IRAN agent active', style: AppTextStyles.mono(size: 10, color: Palantir.accent)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoBriefingPlaceholder(BriefingState bs) {
    return PalantirCard(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.description_outlined, size: 32, color: Palantir.textMuted),
            const SizedBox(height: 12),
            Text('No briefing available', style: AppTextStyles.sans(size: 13, weight: FontWeight.w600, color: Palantir.text)),
            const SizedBox(height: 4),
            Text(
              bs.error != null
                  ? 'API unreachable — using cached data when available'
                  : 'First briefing will be generated shortly',
              style: AppTextStyles.sans(size: 11, color: Palantir.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── OSINT Headline Items ──────────────────────────────────────────

  void _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _osintSourceName(OsintSource source) {
    switch (source) {
      case OsintSource.reuters: return 'Reuters';
      case OsintSource.aljazeera: return 'Al Jazeera';
      case OsintSource.dod: return 'DoD';
      case OsintSource.idf: return 'IDF';
      case OsintSource.ap: return 'AP';
      case OsintSource.centcom: return 'CENTCOM';
      case OsintSource.flightradar: return 'FR24';
      default: return sourceConfig[source]?.label ?? source.name.toUpperCase();
    }
  }

  Color _osintSourceColor(OsintSource source) {
    switch (source) {
      case OsintSource.reuters: return Palantir.orange;
      case OsintSource.aljazeera: return Palantir.success;
      case OsintSource.dod: return Palantir.purple;
      case OsintSource.idf: return Palantir.cyan;
      case OsintSource.ap: return Palantir.warning;
      case OsintSource.centcom: return Palantir.info;
      case OsintSource.flightradar: return Palantir.textMuted;
      default: return Color(sourceConfig[source]?.colorValue ?? 0xFF9CA3AF);
    }
  }

  Widget _buildLiveSourceItem(OsintItem item) {
    final sourceName = _osintSourceName(item.source);
    final sourceColor = _osintSourceColor(item.source);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => _openUrl(item.url ?? ''),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(text: '[$sourceName] ', style: AppTextStyles.mono(size: 10, weight: FontWeight.w700, color: sourceColor)),
                  TextSpan(text: item.title, style: AppTextStyles.sans(size: 11, color: Palantir.text)),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(formatTimestamp(item.timestamp), style: AppTextStyles.mono(size: 11, color: Palantir.textMuted)),
                if (item.url != null && item.url!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.open_in_new, size: 11, color: sourceColor),
                  const SizedBox(width: 2),
                  Text('SOURCE', style: AppTextStyles.mono(size: 11, weight: FontWeight.w600, color: sourceColor, letterSpacing: 0.5)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Utilities ──────────────────────────────────────────────────────

  String _fmtElapsed(Duration d) {
    final days = d.inDays;
    final hours = d.inHours.remainder(24).toString().padLeft(2, '0');
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${days}d $hours:$mins:$secs';
  }

  String _fmtClock(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
