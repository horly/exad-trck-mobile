import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/app_theme.dart';

class ScreenTitle extends StatelessWidget {
  const ScreenTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class SectionPanel extends StatelessWidget {
  const SectionPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: onTap != null,
      label: '$label : $value',
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .11),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const Spacer(),
                    if (onTap != null)
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 17,
                        color: AppTheme.muted,
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VehicleRow extends StatelessWidget {
  const VehicleRow({super.key, required this.vehicle, this.onTap});

  final VehicleData vehicle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (color, label) = _vehicleStatus(context, vehicle);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.directions_car_filled_outlined, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${vehicle.registration}  ·  ${vehicle.speed} km/h',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusPill(label: label, color: color),
                if (onTap != null) ...[
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppTheme.muted,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CorporateVehicleRow extends StatelessWidget {
  const CorporateVehicleRow({
    super.key,
    required this.vehicle,
    this.selected = false,
    this.onTap,
  });

  final VehicleData vehicle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = _vehicleStatus(context, vehicle);
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = selected
        ? colorScheme.secondary.withValues(alpha: .45)
        : Theme.of(context).dividerColor;
    final backgroundColor = selected
        ? colorScheme.secondary.withValues(alpha: .055)
        : colorScheme.surface;

    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.directions_car_filled_outlined,
                  color: statusColor,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vehicle.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.1,
                            ),
                          ),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${vehicle.registration}  ·  ${vehicle.speed} km/h',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: .09),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

(Color, String) _vehicleStatus(BuildContext context, VehicleData vehicle) {
  return switch (vehicle) {
    VehicleData(isMoving: true) => (
      const Color(0xFF0284C7),
      context.tr('moving_now'),
    ),
    VehicleData(isParking: true) => (
      const Color(0xFF0EA5E9),
      context.tr('parking'),
    ),
    VehicleData(isStationaryRunning: true) => (
      const Color(0xFF2563EB),
      context.tr('stationary_running'),
    ),
    VehicleData(trackingStatus: 'maintenance') => (
      const Color(0xFF7C3AED),
      context.tr('maintenance'),
    ),
    VehicleData(trackingStatus: 'inactive') => (
      AppTheme.danger,
      context.tr('inactive'),
    ),
    VehicleData(isOnline: true) => (AppTheme.success, context.tr('online')),
    _ => (AppTheme.warning, context.tr('offline')),
  };
}

class AlertRow extends StatelessWidget {
  const AlertRow({super.key, required this.alert});

  final AlertData alert;

  @override
  Widget build(BuildContext context) {
    final color = alert.severity == 'critical' || alert.severity == 'danger'
        ? AppTheme.danger
        : alert.severity == 'warning'
        ? AppTheme.warning
        : Theme.of(context).colorScheme.secondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (alert.vehicle != null)
                  Text(
                    alert.vehicle!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                if (alert.message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CorporateAlertRow extends StatelessWidget {
  const CorporateAlertRow({super.key, required this.alert});

  final AlertData alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (alert.severity) {
      'critical' || 'high' || 'danger' => AppTheme.danger,
      'medium' || 'warning' => AppTheme.warning,
      _ => Theme.of(context).colorScheme.secondary,
    };
    final isNew = alert.status == 'new';
    final occurredAt = _alertTimestamp(alert.occurredAt);

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isNew
              ? color.withValues(alpha: .28)
              : Theme.of(context).dividerColor,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                alert.severity == 'critical' || alert.severity == 'high'
                    ? Icons.notification_important_outlined
                    : Icons.notifications_active_outlined,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isNew) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            context.tr('new_status'),
                            style: TextStyle(
                              color: color,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (alert.vehicle?.isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.directions_car_outlined,
                          size: 13,
                          color: AppTheme.muted,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            alert.vehicle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (alert.message.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      alert.message,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (occurredAt != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          occurredAt,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _alertTimestamp(String? value) {
  if (value == null || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} · $hour:$minute';
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 34, color: AppTheme.muted),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
