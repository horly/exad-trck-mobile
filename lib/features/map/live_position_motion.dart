import 'dart:math' as math;

import '../../core/models/app_models.dart';

/// Only interpolate fresh GPS updates while the live view remains continuous.
bool canAnimateLivePosition({
  required bool continuous,
  required VehicleData? previous,
  required VehicleData next,
  required GeoCoordinateData current,
  required DateTime now,
}) {
  if (!continuous || !next.isMoving || previous == null) return false;
  final before = DateTime.tryParse(previous.positionTime ?? '');
  final after = DateTime.tryParse(next.positionTime ?? '');
  if (before == null ||
      after == null ||
      next.latitude == null ||
      next.longitude == null) {
    return false;
  }
  final gap = after.difference(before);
  if (gap <= Duration.zero ||
      gap > const Duration(minutes: 1) ||
      now.difference(after) > const Duration(minutes: 2) ||
      after.difference(now) > const Duration(seconds: 5)) {
    return false;
  }
  const radians = math.pi / 180;
  final deltaLat = (next.latitude! - current.latitude) * radians;
  final deltaLng = (next.longitude! - current.longitude) * radians;
  final h =
      math.pow(math.sin(deltaLat / 2), 2) +
      math.cos(current.latitude * radians) *
          math.cos(next.latitude! * radians) *
          math.pow(math.sin(deltaLng / 2), 2);
  final distance = 6371000 * 2 * math.asin(math.sqrt(h.clamp(0, 1)));
  return distance.isFinite && distance > 0 && distance <= 600;
}
