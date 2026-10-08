import 'package:exad_tracking_mobile/core/models/app_models.dart';
import 'package:exad_tracking_mobile/features/map/live_position_motion.dart';
import 'package:flutter_test/flutter_test.dart';

VehicleData sample(String? time, {double longitude = 15.2501}) => VehicleData(
  id: 1,
  name: 'Test',
  registration: 'TEST',
  status: 'active',
  trackingStatus: 'online',
  isOnline: true,
  isMoving: true,
  speed: 30,
  latitude: -4.33,
  longitude: longitude,
  positionTime: time,
);
void main() {
  final now = DateTime.utc(2026, 10, 7, 8);
  bool animate({
    bool continuous = true,
    String? before = '2026-10-07T07:59:40Z',
    String? after = '2026-10-07T07:59:50Z',
    double longitude = 15.2501,
    DateTime? received,
  }) => canAnimateLivePosition(
    continuous: continuous,
    previous: sample(before),
    next: sample(after, longitude: longitude),
    current: const GeoCoordinateData(-4.33, 15.25),
    now: received ?? now,
  );
  test('animate only a fresh live update', () => expect(animate(), isTrue));
  test(
    'selection and resuming the map snap without replaying the cache',
    () => expect(animate(continuous: false), isFalse),
  );
  test(
    'old sessions and GPS gaps snap immediately',
    () => expect(animate(before: '2026-10-06T08:00:00Z'), isFalse),
  );
  test('duplicate, out of order and missing timestamps never animate', () {
    for (final after in [
      '2026-10-07T07:59:40Z',
      '2026-10-07T07:59:30Z',
      null,
      'invalid',
    ]) {
      expect(animate(after: after), isFalse);
    }
  });
  test('stale snapshots and long jumps never draw a catch-up', () {
    expect(animate(received: now.add(const Duration(minutes: 3))), isFalse);
    expect(animate(longitude: 15.3), isFalse);
  });
  test('map payload preserves the GPS position timestamp', () {
    final vehicle = VehicleData.fromMapFeature({
      'geometry': {
        'coordinates': [15.25, -4.33],
      },
      'properties': {'vehicle_id': 1, 'position_time': '2026-10-07T07:59:50Z'},
    });
    expect(vehicle.positionTime, '2026-10-07T07:59:50Z');
  });
}
