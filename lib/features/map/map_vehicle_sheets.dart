import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui_components.dart';

Future<void> showVehicleDetailsSheet(
  BuildContext context,
  SessionController session,
  VehicleData vehicle,
) {
  final future = session.vehicleDetails(vehicle.id);
  final showTechnicalDetails = session.user?.isSuperadmin == true;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SheetFrame(
      title: context.tr(
        showTechnicalDetails ? 'tracker_details' : 'vehicle_details',
      ),
      icon: showTechnicalDetails
          ? Icons.memory_outlined
          : Icons.directions_car_filled_outlined,
      child: FutureBuilder<VehicleDetailData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _SheetError(snapshot.error);
          return _VehicleDetailsContent(data: snapshot.data!);
        },
      ),
    ),
  );
}

Future<void> showVehicleEventsSheet(
  BuildContext context,
  SessionController session,
  VehicleData vehicle,
) {
  final future = session.vehicleEvents(vehicle.id);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SheetFrame(
      title: context.tr('events'),
      icon: Icons.route_outlined,
      subtitle: vehicle.name,
      child: FutureBuilder<List<VehicleEventData>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _SheetError(snapshot.error);
          final events = snapshot.data ?? const [];
          if (events.isEmpty) {
            return EmptyState(
              icon: Icons.event_busy_outlined,
              message: context.tr('no_event'),
            );
          }
          return ListView.separated(
            itemCount: events.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final event = events[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                title: Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (event.message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(event.message),
                    ],
                    if (event.startedAt != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        _formatDateTime(event.startedAt!),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    ),
  );
}

Future<void> showVehicleTripsSheet(
  BuildContext context,
  SessionController session,
  VehicleData vehicle,
  ValueChanged<VehicleTripData> onTripSelected,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _TripsSheet(
      session: session,
      vehicle: vehicle,
      onTripSelected: onTripSelected,
    ),
  );
}

class _TripsSheet extends StatefulWidget {
  const _TripsSheet({
    required this.session,
    required this.vehicle,
    required this.onTripSelected,
  });

  final SessionController session;
  final VehicleData vehicle;
  final ValueChanged<VehicleTripData> onTripSelected;

  @override
  State<_TripsSheet> createState() => _TripsSheetState();
}

class _TripsSheetState extends State<_TripsSheet> {
  String period = 'today';
  late Future<VehicleTripsData> future;

  @override
  void initState() {
    super.initState();
    future = widget.session.vehicleTrips(widget.vehicle.id, period: period);
  }

  void _changePeriod(String value) {
    setState(() {
      period = value;
      future = widget.session.vehicleTrips(widget.vehicle.id, period: period);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: context.tr('trips'),
      icon: Icons.alt_route,
      subtitle: widget.vehicle.name,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'today', label: Text(context.tr('today'))),
                ButtonSegment(
                  value: 'yesterday',
                  label: Text(context.tr('yesterday')),
                ),
                ButtonSegment(
                  value: 'week',
                  label: Text(context.tr('this_week')),
                ),
                ButtonSegment(
                  value: 'current_month',
                  label: Text(context.tr('this_month')),
                ),
              ],
              selected: {period},
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected)
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected)
                      ? Colors.white
                      : AppTheme.ink;
                }),
                side: const WidgetStatePropertyAll(
                  BorderSide(color: AppTheme.border),
                ),
                shape: const WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
              onSelectionChanged: (selection) => _changePeriod(selection.first),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<VehicleTripsData>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return _SheetError(snapshot.error);
                final data = snapshot.data!;
                if (!data.trackingConfigured || data.trips.isEmpty) {
                  return EmptyState(
                    icon: Icons.route_outlined,
                    message: context.tr('no_trip'),
                  );
                }
                return Column(
                  children: [
                    _TripsSummary(data: data),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.builder(
                        itemCount: data.trips.length,
                        itemBuilder: (context, index) {
                          final trip = data.trips[index];
                          final showDate =
                              index == 0 ||
                              data.trips[index - 1].date != trip.date;
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == data.trips.length - 1 ? 0 : 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showDate) ...[
                                  _TripDateHeader(date: trip.date),
                                  const SizedBox(height: 8),
                                ],
                                _TripTimelineCard(
                                  trip: trip,
                                  onTap: () {
                                    Navigator.pop(context);
                                    widget.onTripSelected(trip);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (subtitle != null) Text(subtitle!),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('close'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 26),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleDetailsContent extends StatelessWidget {
  const _VehicleDetailsContent({required this.data});

  final VehicleDetailData data;

  @override
  Widget build(BuildContext context) {
    final vehicle = data.vehicle;
    final tracker = data.tracker;
    final location = data.location;
    final power = data.power;
    final gsm = data.gsm;
    final diagnostic = data.diagnostic;
    final obd = data.obdCan;
    final sections = <Widget>[
      _DetailSection(
        title: vehicle.registration == '-'
            ? vehicle.name
            : '${vehicle.name} (${vehicle.registration})',
        icon: Icons.directions_car_filled_outlined,
        accent: Theme.of(context).colorScheme.secondary,
        child: Column(
          children: [
            if (tracker != null) ...[
              _DetailLine(
                icon: Icons.memory_outlined,
                label: context.tr('model'),
                value: _trackerModelLabel(tracker),
              ),
              _DetailLine(
                icon: Icons.tag_outlined,
                label: 'ID',
                value: tracker.imei,
              ),
            ],
            _DetailLine(
              icon: Icons.groups_outlined,
              label: context.tr('fleet'),
              value: vehicle.fleet?.name ?? '-',
            ),
            _DetailLine(
              icon: Icons.circle,
              label: context.tr('status'),
              value: vehicle.isOnline
                  ? context.tr('online')
                  : context.tr('offline'),
              badgeColor: vehicle.isOnline ? AppTheme.success : AppTheme.danger,
            ),
          ],
        ),
      ),
      _DetailSection(
        title: context.tr('location'),
        icon: Icons.location_on_outlined,
        accent: const Color(0xFF1597C4),
        updatedAt: location?.updatedAt,
        child: location == null
            ? _EmptyDetail(message: context.tr('no_position'))
            : Column(
                children: [
                  _DetailLine(
                    icon: Icons.signal_cellular_alt,
                    label: context.tr('gps_quality'),
                    value: _percent(location.gpsQualityPercent),
                  ),
                  _DetailLine(
                    icon: Icons.location_searching,
                    label: context.tr('coordinates'),
                    value: _coordinates(location.latitude, location.longitude),
                  ),
                  _DetailLine(
                    icon: Icons.local_parking_outlined,
                    label: context.tr('movement_state'),
                    value: _movementLabel(context, location),
                  ),
                  _DetailLine(
                    icon: Icons.explore_outlined,
                    label: context.tr('heading'),
                    value: _direction(context, location.headingDegrees),
                  ),
                  _DetailLine(
                    icon: Icons.home_outlined,
                    label: context.tr('address'),
                    value: _text(location.address),
                  ),
                  _DetailLine(
                    icon: Icons.height,
                    label: context.tr('altitude'),
                    value: location.altitudeMeters == null
                        ? '-'
                        : '${_number(location.altitudeMeters)} m',
                  ),
                ],
              ),
      ),
      _DetailSection(
        title: context.tr('driver'),
        icon: Icons.badge_outlined,
        accent: const Color(0xFFE5A000),
        child: data.driver == null
            ? _EmptyDetail(message: context.tr('no_driver_identified'))
            : Column(
                children: [
                  _DetailLine(
                    icon: Icons.person_outline,
                    label: context.tr('name'),
                    value: data.driver!.fullName,
                  ),
                  _DetailLine(
                    icon: Icons.assignment_ind_outlined,
                    label: context.tr('employee_id'),
                    value: _text(data.driver!.employeeId),
                  ),
                  _DetailLine(
                    icon: Icons.apartment_outlined,
                    label: context.tr('department'),
                    value: _text(data.driver!.department),
                  ),
                  _DetailLine(
                    icon: Icons.key_outlined,
                    label: context.tr('identifier'),
                    value: _text(data.driver!.identifierUid),
                  ),
                  _DetailLine(
                    icon: Icons.phone_outlined,
                    label: context.tr('phone'),
                    value: _text(data.driver!.phone),
                  ),
                  _DetailLine(
                    icon: Icons.check_circle_outline,
                    label: context.tr('status'),
                    value: _text(data.driver!.status),
                  ),
                ],
              ),
      ),
      _DetailSection(
        title: context.tr('power'),
        icon: Icons.battery_charging_full_outlined,
        accent: AppTheme.success,
        updatedAt: power?.updatedAt,
        child: power == null
            ? _EmptyDetail(message: context.tr('data_unavailable'))
            : Column(
                children: [
                  _DetailLine(
                    icon: Icons.electric_bolt_outlined,
                    label: context.tr('external_voltage'),
                    value: _voltage(power.externalVoltage),
                  ),
                  _DetailLine(
                    icon: Icons.battery_5_bar_outlined,
                    label: context.tr('internal_battery'),
                    value: _voltage(power.internalBatteryVoltage),
                  ),
                  _DetailLine(
                    icon: Icons.battery_4_bar_outlined,
                    label: context.tr('battery_level'),
                    value: _percent(power.batteryLevelPercent),
                  ),
                  _DetailLine(
                    icon: Icons.power_settings_new,
                    label: context.tr('ignition'),
                    value: power.ignition == null
                        ? '-'
                        : power.ignition!
                        ? context.tr('on')
                        : context.tr('off'),
                  ),
                ],
              ),
      ),
      _DetailSection(
        title: 'GSM',
        icon: Icons.cell_tower_outlined,
        accent: const Color(0xFF7C3AED),
        updatedAt: gsm?.updatedAt,
        child: gsm == null
            ? _EmptyDetail(message: context.tr('data_unavailable'))
            : Column(
                children: [
                  _DetailLine(
                    icon: Icons.signal_cellular_alt,
                    label: context.tr('signal'),
                    value: _percent(gsm.signalPercent),
                  ),
                  _DetailLine(
                    icon: Icons.cell_tower_outlined,
                    label: context.tr('operator'),
                    value: _text(gsm.operatorName),
                  ),
                  _DetailLine(
                    icon: Icons.sim_card_outlined,
                    label: 'SIM',
                    value: _text(gsm.simNumber),
                  ),
                  _DetailLine(
                    icon: Icons.code_outlined,
                    label: 'Codec',
                    value: _text(gsm.codec),
                  ),
                ],
              ),
      ),
      _DetailSection(
        title: context.tr('tracker_diagnostic'),
        icon: Icons.tune,
        accent: const Color(0xFF7C3AED),
        updatedAt: diagnostic?.updatedAt,
        child: diagnostic == null
            ? _EmptyDetail(message: context.tr('data_unavailable'))
            : Column(
                children: [
                  _DetailLine(
                    icon: Icons.satellite_alt_outlined,
                    label: context.tr('satellites'),
                    value: diagnostic.satellites?.toString() ?? '-',
                  ),
                  _DetailLine(
                    icon: Icons.lan_outlined,
                    label: context.tr('protocol'),
                    value: _text(diagnostic.protocol),
                  ),
                  _DetailLine(
                    icon: Icons.key_outlined,
                    label: context.tr('identifier'),
                    value: _text(diagnostic.driverIdentifierUid),
                  ),
                  _DetailLine(
                    icon: Icons.route_outlined,
                    label: context.tr('odometer'),
                    value: diagnostic.odometerKm == null
                        ? '-'
                        : '${_number(diagnostic.odometerKm, decimals: 2)} km',
                  ),
                  _DetailLine(
                    icon: Icons.timer_outlined,
                    label: context.tr('engine_hours'),
                    value: diagnostic.engineSeconds == null
                        ? '-'
                        : _duration(diagnostic.engineSeconds!),
                  ),
                  _DetailLine(
                    icon: Icons.toggle_on_outlined,
                    label: context.tr('inputs_outputs'),
                    value: diagnostic.ioCount.toString(),
                  ),
                  _DetailLine(
                    icon: Icons.sensors_outlined,
                    label: context.tr('sensors'),
                    value: diagnostic.sensorCount.toString(),
                  ),
                ],
              ),
      ),
      _DetailSection(
        title: 'OBD / CAN',
        icon: Icons.car_repair_outlined,
        accent: const Color(0xFF0E9F8A),
        updatedAt: obd?.updatedAt,
        child: obd == null || !obd.hasData
            ? _EmptyDetail(message: context.tr('no_obd_data'))
            : Column(
                children: [
                  _DetailLine(
                    icon: Icons.timer_outlined,
                    label: context.tr('runtime'),
                    value: obd.runtimeSeconds == null
                        ? '-'
                        : _duration(obd.runtimeSeconds!),
                  ),
                  _DetailLine(
                    icon: Icons.speed_outlined,
                    label: 'RPM',
                    value: obd.rpm?.toString() ?? '-',
                  ),
                  _DetailLine(
                    icon: Icons.speed_outlined,
                    label: context.tr('speed'),
                    value: obd.speedKmh == null ? '-' : '${obd.speedKmh} km/h',
                  ),
                  _DetailLine(
                    icon: Icons.tune,
                    label: context.tr('throttle'),
                    value: _percent(obd.throttlePercent),
                  ),
                  _DetailLine(
                    icon: Icons.device_thermostat,
                    label: context.tr('engine_temperature'),
                    value: obd.engineTemperatureC == null
                        ? '-'
                        : '${_number(obd.engineTemperatureC)} °C',
                  ),
                  _DetailLine(
                    icon: Icons.electric_bolt_outlined,
                    label: context.tr('module_voltage'),
                    value: _voltage(obd.moduleVoltage),
                  ),
                  _DetailLine(
                    icon: Icons.monitor_weight_outlined,
                    label: context.tr('engine_load'),
                    value: _percent(obd.engineLoadPercent),
                  ),
                  _DetailLine(
                    icon: Icons.local_gas_station_outlined,
                    label: context.tr('fuel_level'),
                    value: _percent(obd.fuelLevelPercent),
                  ),
                  _DetailLine(
                    icon: Icons.warning_amber_outlined,
                    label: context.tr('fault_distance'),
                    value: obd.faultDistanceKm == null
                        ? '-'
                        : '${obd.faultDistanceKm} km',
                  ),
                  _DetailLine(
                    icon: Icons.bug_report_outlined,
                    label: context.tr('errors'),
                    value: obd.errorsCount?.toString() ?? '-',
                  ),
                  _DetailLine(
                    icon: Icons.restart_alt,
                    label: context.tr('distance_since_clear'),
                    value: obd.distanceSinceClearKm == null
                        ? '-'
                        : '${obd.distanceSinceClearKm} km',
                  ),
                ],
              ),
      ),
      _DetailSection(
        title: context.tr('recent_events'),
        icon: Icons.notifications_active_outlined,
        accent: Theme.of(context).colorScheme.primary,
        child: data.recentEvents.isEmpty
            ? _EmptyDetail(message: context.tr('no_event'))
            : Column(
                children: data.recentEvents
                    .map(
                      (event) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.alt_route, size: 19),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (event.message.isNotEmpty)
                                    Text(event.message),
                                ],
                              ),
                            ),
                            if (event.startedAt != null)
                              Text(
                                _formatDateTime(event.startedAt!),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 760;
        final itemWidth = twoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: sections
                .map((section) => SizedBox(width: itemWidth, child: section))
                .toList(),
          ),
        );
      },
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
    this.updatedAt,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;
  final String? updatedAt;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            child,
            if (updatedAt != null) ...[
              const Divider(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatDateTime(updatedAt!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
    this.badgeColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 104,
            child: Text(label, style: const TextStyle(color: AppTheme.muted)),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: badgeColor == null
                  ? Text(
                      value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor!.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        value,
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripsSummary extends StatelessWidget {
  const _TripsSummary({required this.data});

  final VehicleTripsData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _TripSummaryMetric(
            icon: Icons.alt_route,
            value: data.count.toString(),
            label: context.tr('trips'),
          ),
          const _TripSummaryDivider(),
          _TripSummaryMetric(
            icon: Icons.route_outlined,
            value: '${_number(data.distanceKm, decimals: 2)} km',
            label: context.tr('distance'),
          ),
          const _TripSummaryDivider(),
          _TripSummaryMetric(
            icon: Icons.schedule_outlined,
            value: _duration(data.durationSeconds),
            label: context.tr('duration'),
          ),
        ],
      ),
    );
  }
}

class _TripSummaryMetric extends StatelessWidget {
  const _TripSummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _TripSummaryDivider extends StatelessWidget {
  const _TripSummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: AppTheme.border,
    );
  }
}

class _TripDateHeader extends StatelessWidget {
  const _TripDateHeader({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 15,
          color: Theme.of(context).colorScheme.secondary,
        ),
        const SizedBox(width: 7),
        Text(
          date,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _TripTimelineCard extends StatelessWidget {
  const _TripTimelineCard({required this.trip, required this.onTap});

  final VehicleTripData trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: trip.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 10, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: trip.color.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.alt_route,
                              size: 17,
                              color: trip.color,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              context.trFormat('trip_number', {
                                'number': trip.index,
                              }),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 21,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 11),
                      _TripEndpoint(
                        time: trip.startTime,
                        address: trip.startAddress,
                        color: trip.color,
                        connectsToNext: true,
                      ),
                      _TripEndpoint(
                        time: trip.endTime,
                        address: trip.endAddress,
                        color: trip.color,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.only(top: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppTheme.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            _TripCompactMetric(
                              tooltip: context.tr('distance'),
                              icon: Icons.route_outlined,
                              value:
                                  '${_number(trip.distanceKm, decimals: 2)} km',
                            ),
                            _TripCompactMetric(
                              tooltip: context.tr('duration'),
                              icon: Icons.schedule_outlined,
                              value: _duration(trip.durationSeconds),
                            ),
                            _TripCompactMetric(
                              tooltip: context.tr('average_speed'),
                              icon: Icons.speed_outlined,
                              value: '${_number(trip.averageSpeedKmh)} km/h',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripEndpoint extends StatelessWidget {
  const _TripEndpoint({
    required this.time,
    required this.address,
    required this.color,
    this.connectsToNext = false,
  });

  final String time;
  final String address;
  final Color color;
  final bool connectsToNext;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              time,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 18,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (connectsToNext)
                  Positioned(
                    top: 9,
                    bottom: -9,
                    child: Container(
                      width: 2,
                      color: color.withValues(alpha: .5),
                    ),
                  ),
                Positioned(
                  top: 3,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: connectsToNext ? 10 : 0),
              child: Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripCompactMetric extends StatelessWidget {
  const _TripCompactMetric({
    required this.tooltip,
    required this.icon,
    required this.value,
  });

  final String tooltip;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.muted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetError extends StatelessWidget {
  const _SheetError(this.error);

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      message: error?.toString() ?? 'Erreur',
    );
  }
}

String _formatDateTime(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year} '
      '${two(parsed.hour)}:${two(parsed.minute)}';
}

String _duration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}min';
  return '${minutes}min';
}

String _text(String? value) {
  if (value == null || value.trim().isEmpty) return '-';
  return value.trim();
}

String _trackerModelLabel(VehicleTrackerDetail tracker) {
  final brand = _text(tracker.brand);
  final model = _text(tracker.model);
  if (brand == '-' && model == '-') return '-';
  final normalizedBrand = brand == '-'
      ? ''
      : '${brand[0].toUpperCase()}${brand.substring(1)}';
  return [
    normalizedBrand,
    if (model != '-') model,
  ].where((value) => value.isNotEmpty).join(' ');
}

String _number(num? value, {int decimals = 1}) {
  if (value == null) return '-';
  final formatted = value.toStringAsFixed(decimals);
  return formatted.replaceFirst(RegExp(r'\.0+$'), '');
}

String _percent(num? value) => value == null ? '-' : '${_number(value)}%';

String _voltage(num? value) => value == null ? '-' : '${_number(value)} V';

String _coordinates(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return '-';
  return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

String _movementLabel(BuildContext context, VehicleLocationDetail location) {
  if (location.ignition == false) {
    final startedAt = DateTime.tryParse(location.parkingStartedAt ?? '');
    if (startedAt == null) return context.tr('parking');
    final elapsed = DateTime.now().difference(startedAt.toLocal()).inSeconds;
    return '${context.tr('parking')} · ${_duration(elapsed.clamp(0, 315360000))}';
  }
  if (location.movement == true) return context.tr('moving_now');
  return context.tr('stopped');
}

String _direction(BuildContext context, int? angle) {
  if (angle == null) return '-';
  final french = Localizations.localeOf(context).languageCode == 'fr';
  final directions = french
      ? const ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO']
      : const ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  final normalized = ((angle % 360) + 360) % 360;
  final index = ((normalized / 45).round()) % 8;
  return '${directions[index]} · $normalized°';
}
