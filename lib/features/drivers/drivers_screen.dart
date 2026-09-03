import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui_components.dart';

typedef DriverLoader = Future<List<DriverData>> Function();

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key, required this.session, this.loadDrivers});

  final SessionController session;
  final DriverLoader? loadDrivers;

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  List<DriverData>? _drivers;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final drivers =
          await (widget.loadDrivers?.call() ?? widget.session.drivers());
      if (!mounted) return;
      setState(() => _drivers = drivers);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = context.tr('data_unavailable'));
    }
  }

  List<DriverData> get _filteredDrivers {
    final normalized = _query.trim().toLowerCase();
    final drivers = _drivers ?? const <DriverData>[];
    if (normalized.isEmpty) return drivers;

    return drivers
        .where((driver) {
          final searchable = [
            driver.fullName,
            driver.employeeId,
            driver.phone,
            driver.email,
            driver.fleet?.name,
            driver.department?.name,
            ...driver.vehicles.expand(
              (vehicle) => [vehicle.name, vehicle.registration],
            ),
          ].whereType<String>().join(' ').toLowerCase();
          return searchable.contains(normalized);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final drivers = _filteredDrivers;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('drivers'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          children: [
            ScreenTitle(
              title: context.tr('drivers'),
              subtitle: context.trFormat('driver_count', {
                'count': _drivers?.length ?? 0,
              }),
            ),
            const SizedBox(height: 18),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: context.tr('search_driver'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 18),
            if (_drivers == null && _error == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              SectionPanel(
                child: EmptyState(
                  icon: Icons.cloud_off_outlined,
                  message: _error!,
                ),
              )
            else if (drivers.isEmpty)
              SectionPanel(
                child: EmptyState(
                  icon: Icons.badge_outlined,
                  message: context.tr('no_driver'),
                ),
              )
            else
              ...drivers.map(
                (driver) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DriverCard(driver: driver),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});

  final DriverData driver;

  @override
  Widget build(BuildContext context) {
    final statusColor = driver.isActive ? AppTheme.success : AppTheme.muted;
    final vehicles = driver.vehicles
        .map(
          (vehicle) => vehicle.registration == '-'
              ? vehicle.name
              : '${vehicle.name} (${vehicle.registration})',
        )
        .join(', ');

    return SectionPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5A000).withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Color(0xFFE5A000),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  driver.fullName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusPill(
                label: context.tr(driver.isActive ? 'active' : 'inactive'),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DriverInfoLine(
            icon: Icons.assignment_ind_outlined,
            label: context.tr('employee_id'),
            value: _text(driver.employeeId),
          ),
          _DriverInfoLine(
            icon: Icons.phone_outlined,
            label: context.tr('phone'),
            value: _text(driver.phone),
          ),
          _DriverInfoLine(
            icon: Icons.email_outlined,
            label: context.tr('email'),
            value: _text(driver.email),
          ),
          _DriverInfoLine(
            icon: Icons.local_shipping_outlined,
            label: context.tr('fleet'),
            value: driver.fleet?.name ?? '-',
          ),
          _DriverInfoLine(
            icon: Icons.apartment_outlined,
            label: context.tr('department'),
            value: driver.department?.name ?? '-',
          ),
          _DriverInfoLine(
            icon: Icons.directions_car_filled_outlined,
            label: context.tr('authorized_vehicles'),
            value: vehicles.isEmpty ? '-' : vehicles,
          ),
        ],
      ),
    );
  }

  String _text(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? '-' : normalized;
  }
}

class _DriverInfoLine extends StatelessWidget {
  const _DriverInfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppTheme.muted),
          const SizedBox(width: 8),
          SizedBox(
            width: 112,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
