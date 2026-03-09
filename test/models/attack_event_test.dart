// ── AttackEvent Model Tests ──────────────────────────────────────
// Tests for fromJson, toJson, copyWith, enum handling.

import 'package:flutter_test/flutter_test.dart';
import 'package:breach/models/attack_event.dart';

void main() {
  final sampleJson = {
    'id': 'test-001',
    'timestamp': 1709085600000,
    'type': 'ballistic',
    'origin': 'IRGC',
    'target': 'UAE',
    'status': 'intercepted',
    'details': 'Ballistic missile intercepted over Abu Dhabi',
    'source': 'CENTCOM',
    'sourceUrl': 'https://www.centcom.mil/article/123',
  };

  group('AttackEvent.fromJson', () {
    test('parses all fields correctly', () {
      final event = AttackEvent.fromJson(sampleJson);
      expect(event.id, 'test-001');
      expect(event.timestamp, 1709085600000);
      expect(event.type, AttackType.ballistic);
      expect(event.origin, 'IRGC');
      expect(event.target, 'UAE');
      expect(event.status, EventStatus.intercepted);
      expect(event.details, 'Ballistic missile intercepted over Abu Dhabi');
      expect(event.source, 'CENTCOM');
      expect(event.sourceUrl, 'https://www.centcom.mil/article/123');
    });

    test('defaults to AttackType.general for unknown type', () {
      final json = {...sampleJson, 'type': 'unknown_type'};
      final event = AttackEvent.fromJson(json);
      expect(event.type, AttackType.general);
    });

    test('defaults to EventStatus.ongoing for unknown status', () {
      final json = {...sampleJson, 'status': 'unknown_status'};
      final event = AttackEvent.fromJson(json);
      expect(event.status, EventStatus.ongoing);
    });

    test('handles null source and sourceUrl', () {
      final json = Map<String, dynamic>.from(sampleJson)
        ..remove('source')
        ..remove('sourceUrl');
      final event = AttackEvent.fromJson(json);
      expect(event.source, isNull);
      expect(event.sourceUrl, isNull);
    });
  });

  group('AttackEvent.toJson', () {
    test('serializes all fields', () {
      final event = AttackEvent.fromJson(sampleJson);
      final json = event.toJson();
      expect(json['id'], 'test-001');
      expect(json['type'], 'ballistic');
      expect(json['status'], 'intercepted');
      expect(json['origin'], 'IRGC');
    });

    test('roundtrip: fromJson -> toJson -> fromJson preserves data', () {
      final original = AttackEvent.fromJson(sampleJson);
      final roundtripped = AttackEvent.fromJson(original.toJson());
      expect(roundtripped.id, original.id);
      expect(roundtripped.timestamp, original.timestamp);
      expect(roundtripped.type, original.type);
      expect(roundtripped.origin, original.origin);
      expect(roundtripped.target, original.target);
      expect(roundtripped.status, original.status);
      expect(roundtripped.details, original.details);
      expect(roundtripped.source, original.source);
      expect(roundtripped.sourceUrl, original.sourceUrl);
    });
  });

  group('AttackEvent.copyWith', () {
    test('copies with changed fields', () {
      final event = AttackEvent.fromJson(sampleJson);
      final modified = event.copyWith(
        status: EventStatus.impact,
        details: 'Updated details',
      );
      expect(modified.status, EventStatus.impact);
      expect(modified.details, 'Updated details');
      // Unchanged fields preserved
      expect(modified.id, event.id);
      expect(modified.type, event.type);
      expect(modified.origin, event.origin);
    });

    test('preserves all fields when no arguments', () {
      final event = AttackEvent.fromJson(sampleJson);
      final copy = event.copyWith();
      expect(copy.id, event.id);
      expect(copy.timestamp, event.timestamp);
      expect(copy.type, event.type);
      expect(copy.status, event.status);
    });
  });

  group('AttackType enum', () {
    test('has all expected values', () {
      expect(AttackType.values, containsAll([
        AttackType.ballistic,
        AttackType.drone,
        AttackType.cyber,
        AttackType.artillery,
        AttackType.cruise,
        AttackType.sabotage,
        AttackType.general,
      ]));
    });

    test('.name returns string representation', () {
      expect(AttackType.ballistic.name, 'ballistic');
      expect(AttackType.drone.name, 'drone');
      expect(AttackType.general.name, 'general');
    });
  });

  group('EventStatus enum', () {
    test('has all expected values', () {
      expect(EventStatus.values, containsAll([
        EventStatus.intercepted,
        EventStatus.impact,
        EventStatus.ongoing,
        EventStatus.neutralized,
      ]));
    });
  });
}
