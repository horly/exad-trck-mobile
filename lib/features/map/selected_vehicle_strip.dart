import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/fuel_level_badge.dart';
import '../../shared/widgets/vehicle_marker_style.dart';

class SelectedVehicleTopStrip extends StatelessWidget {
  const SelectedVehicleTopStrip({
    super.key,
    required this.vehicle,
    this.details,
  });

  final VehicleData vehicle;
  final VehicleDetailData? details;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gpsQualityPercent =
        vehicle.gpsQualityPercent ?? details?.location?.gpsQualityPercent;
    final networkSignalPercent =
        vehicle.networkSignalPercent ?? details?.gsm?.signalPercent;
    final batteryLevelPercent =
        vehicle.batteryLevelPercent ??
        details?.power?.effectiveBatteryLevelPercent;
    final gpsAvailable =
        vehicle.hasAvailableGps ||
        (vehicle.isOnline && (gpsQualityPercent ?? 0) > 0);
    final isParking = vehicle.isParking || details?.location?.ignition == false;
    final gpsColor = gpsAvailable ? AppTheme.success : AppTheme.danger;
    final networkColor = _levelColor(networkSignalPercent);
    final batteryColor = _levelColor(batteryLevelPercent);

    return Material(
      color: scheme.surface,
      elevation: 3,
      shadowColor: const Color(0x260F172A),
      child: SizedBox(
        height: 70,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    vehicleMarkerIcon(vehicle),
                    size: 18,
                    color: vehicleMarkerColor(vehicle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      vehicle.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (vehicle.fuel != null) ...[
                    const SizedBox(width: 8),
                    FuelLevelBadge(fuel: vehicle.fuel!, compact: true),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    _lastSignalLabel(context),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _TrackingMetric(
                      icon: gpsAvailable
                          ? Icons.gps_fixed_rounded
                          : Icons.gps_off_rounded,
                      value: context.tr(
                        gpsAvailable ? 'gps_active' : 'gps_unavailable',
                      ),
                      color: gpsColor,
                    ),
                  ),
                  Expanded(
                    child: _TrackingMetric(
                      icon: vehicle.isOnline
                          ? Icons.signal_cellular_alt_rounded
                          : Icons.signal_cellular_off_rounded,
                      value: networkSignalPercent != null
                          ? _percent(networkSignalPercent)
                          : vehicle.isOnline
                          ? context.tr('connected')
                          : context.tr('not_available_short'),
                      color: networkSignalPercent == null && vehicle.isOnline
                          ? AppTheme.success
                          : networkColor,
                    ),
                  ),
                  Expanded(
                    child: _TrackingMetric(
                      icon: Icons.battery_5_bar_rounded,
                      value: batteryLevelPercent == null
                          ? context.tr('not_available_short')
                          : _percent(batteryLevelPercent),
                      color: batteryColor,
                    ),
                  ),
                  Expanded(
                    child: _TrackingMetric(
                      icon: isParking
                          ? Icons.local_parking_rounded
                          : Icons.speed_rounded,
                      value: _movementValue(context),
                      color: scheme.onSurfaceVariant,
                      circledIcon: isParking,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _percent(int? value) {
    return value == null ? '--%' : '${value.clamp(0, 100)}%';
  }

  Color _levelColor(int? value) {
    if (value == null) return AppTheme.muted;
    if (value >= 50) return AppTheme.success;
    if (value >= 20) return AppTheme.warning;
    return AppTheme.danger;
  }

  String _movementValue(BuildContext context) {
    final isParking = vehicle.isParking || details?.location?.ignition == false;
    if (!isParking) return '${vehicle.speed} km/h';

    final startedAt = DateTime.tryParse(
      details?.location?.parkingStartedAt ?? '',
    )?.toLocal();
    if (startedAt == null) return context.tr('parking');

    final elapsed = DateTime.now().difference(startedAt);
    final minutes = elapsed.isNegative ? 0 : elapsed.inMinutes;
    if (minutes < 1) return '< 1min';
    if (minutes < 60) return '${minutes}min';

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours < 24) {
      return '${hours}h${remainingMinutes.toString().padLeft(2, '0')}min';
    }

    final days = hours ~/ 24;
    final remainingHours = hours % 24;
    return '${days}j ${remainingHours}h${remainingMinutes.toString().padLeft(2, '0')}min';
  }

  String _lastSignalLabel(BuildContext context) {
    final parsed = DateTime.tryParse(vehicle.lastSignalAt ?? '')?.toLocal();
    if (parsed == null) return '';
    final difference = DateTime.now().difference(parsed);
    if (difference.isNegative || difference.inSeconds < 5) {
      return context.tr('signal_just_now');
    }
    if (difference.inMinutes < 1) {
      return context.trFormat('signal_seconds_ago', {
        'count': difference.inSeconds,
      });
    }
    if (difference.inHours < 1) {
      return context.trFormat('signal_minutes_ago', {
        'count': difference.inMinutes,
      });
    }
    return context.trFormat('signal_hours_ago', {'count': difference.inHours});
  }
}

class _TrackingMetric extends StatelessWidget {
  const _TrackingMetric({
    required this.icon,
    required this.value,
    required this.color,
    this.circledIcon = false,
  });

  final IconData icon;
  final String value;
  final Color color;
  final bool circledIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (circledIcon)
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.4),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 12, color: color),
          )
        else
          Icon(icon, size: 17, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
