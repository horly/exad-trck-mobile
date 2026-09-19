import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui_components.dart';

enum _NotificationView { events, alerts }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.session,
    this.initialCategory,
    this.highlightedId,
  });

  final SessionController session;
  final String? initialCategory;
  final int? highlightedId;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<VehicleEventData>? _events;
  List<AlertData>? _alerts;
  String? _error;
  late _NotificationView _view;

  @override
  void initState() {
    super.initState();
    _view = widget.initialCategory == 'alert'
        ? _NotificationView.alerts
        : _NotificationView.events;
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _error = null);
    try {
      final values = await Future.wait<Object>([
        widget.session.notificationEvents(),
        widget.session.notificationAlerts(),
      ]);
      if (!mounted) return;
      setState(() {
        _events = values[0] as List<VehicleEventData>;
        _alerts = values[1] as List<AlertData>;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = context.tr('data_unavailable'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = _events == null && _alerts == null && _error == null;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          ScreenTitle(
            title: context.tr('notifications'),
            subtitle: context.tr('notifications_help'),
          ),
          const SizedBox(height: 18),
          SegmentedButton<_NotificationView>(
            segments: [
              ButtonSegment(
                value: _NotificationView.events,
                icon: const Icon(Icons.route_outlined),
                label: Text(context.tr('events')),
              ),
              ButtonSegment(
                value: _NotificationView.alerts,
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(context.tr('alerts')),
              ),
            ],
            selected: {_view},
            showSelectedIcon: false,
            onSelectionChanged: (value) => setState(() => _view = value.first),
          ),
          const SizedBox(height: 16),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(36),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            SectionPanel(
              child: Column(
                children: [
                  EmptyState(icon: Icons.cloud_off_outlined, message: _error!),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.tr('retry')),
                  ),
                ],
              ),
            )
          else if (_view == _NotificationView.events)
            ..._eventContent()
          else
            ..._alertContent(),
        ],
      ),
    );
  }

  List<Widget> _eventContent() {
    final events = _events ?? const <VehicleEventData>[];
    if (events.isEmpty) {
      return [
        SectionPanel(
          child: EmptyState(
            icon: Icons.event_busy_outlined,
            message: context.tr('notification_events_empty'),
          ),
        ),
      ];
    }
    return events
        .map(
          (event) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _VehicleEventRow(
              event: event,
              highlighted: event.id == widget.highlightedId,
            ),
          ),
        )
        .toList(growable: false);
  }

  List<Widget> _alertContent() {
    final alerts = _alerts ?? const <AlertData>[];
    if (alerts.isEmpty) {
      return [
        SectionPanel(
          child: EmptyState(
            icon: Icons.notifications_none_outlined,
            message: context.tr('notification_alerts_empty'),
          ),
        ),
      ];
    }
    return alerts
        .map(
          (alert) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: alert.id == widget.highlightedId
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : null,
              ),
              child: CorporateAlertRow(alert: alert),
            ),
          ),
        )
        .toList(growable: false);
  }
}

class _VehicleEventRow extends StatelessWidget {
  const _VehicleEventRow({required this.event, required this.highlighted});

  final VehicleEventData event;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = _visual;
    final timestamp = _formatTimestamp(context, event.startedAt);
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: highlighted ? scheme.primary : Theme.of(context).dividerColor,
          width: highlighted ? 2 : 1,
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
                color: color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (event.vehicle?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.directions_car_outlined, size: 13),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            event.vehicle!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (event.message.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.message,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (timestamp != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          timestamp,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 9.5,
                          ),
                        ),
                        if (event.latitude != null &&
                            event.longitude != null) ...[
                          const Spacer(),
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: color,
                          ),
                        ],
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

  (IconData, Color) get _visual {
    final value = '${event.type} ${event.title}'.toLowerCase();
    if (value.contains('ignition') || value.contains('contact')) {
      return (Icons.power_settings_new_rounded, const Color(0xFF2563EB));
    }
    if (value.contains('movement') || value.contains('mouvement')) {
      return (Icons.route_rounded, const Color(0xFF0891B2));
    }
    if (value.contains('signal') || value.contains('offline')) {
      return (
        Icons.signal_wifi_statusbar_connected_no_internet_4,
        AppTheme.warning,
      );
    }
    if (value.contains('speed') || value.contains('vitesse')) {
      return (Icons.speed_rounded, AppTheme.danger);
    }
    return (Icons.notifications_active_outlined, const Color(0xFF7C3AED));
  }
}

String? _formatTimestamp(BuildContext context, String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final date = DateTime.tryParse(raw)?.toLocal();
  if (date == null) return raw;
  final localizations = MaterialLocalizations.of(context);
  final day = localizations.formatShortDate(date);
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date));
  return '$day · $time';
}
