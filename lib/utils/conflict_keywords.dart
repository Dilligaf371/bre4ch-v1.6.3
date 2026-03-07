// =============================================================================
// BRE4CH - Conflict Keywords
// Used by event_feed_provider for headline filtering
// =============================================================================

/// Keywords that indicate a headline is related to the Iran-Israel theatre.
/// Used to filter RSS/news feeds for conflict-relevant items.
const List<String> conflictKeywords = [
  // English
  'iran',
  'israel',
  'military',
  'strike',
  'missile',
  'kill',
  'attack',
  'war',
  'drone',
  'bomb',
  'nuclear',
  'hezbollah',
  'gaza',
  'gulf',
  'navy',
  'air force',
  'evacuation',
  'repatriation',
  'expats',
  // Arabic
  'صاروخ',    // missile
  'هجوم',     // attack
  'طائرة مسيرة', // drone
  'قصف',      // shelling
  'حرب',      // war
  'نووي',     // nuclear
  'حزب الله',  // Hezbollah
  'غزة',      // Gaza
  'إيران',    // Iran
  'عسكري',    // military
  'إجلاء',    // evacuation
];

/// Checks whether a given text contains any conflict keyword.
///
/// Case-insensitive match.
bool containsConflictKeyword(String text) {
  final lower = text.toLowerCase();
  return conflictKeywords.any((kw) => lower.contains(kw));
}
