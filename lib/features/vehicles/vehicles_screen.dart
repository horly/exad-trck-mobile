import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui_components.dart';

enum VehicleFilter { all, online, offline }

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  String query = '';
  VehicleFilter filter = VehicleFilter.all;

  List<VehicleData> get filteredVehicles {
    return widget.session.vehicles.where((vehicle) {
      final normalized = query.trim().toLowerCase();
      final matchesText =
          normalized.isEmpty ||
          vehicle.name.toLowerCase().contains(normalized) ||
          vehicle.registration.toLowerCase().contains(normalized);
      final matchesStatus = switch (filter) {
        VehicleFilter.all => true,
        VehicleFilter.online => vehicle.isOnline,
        VehicleFilter.offline => !vehicle.isOnline,
      };
      return matchesText && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = filteredVehicles;
    return RefreshIndicator(
      onRefresh: widget.session.refreshWorkspace,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          ScreenTitle(
            title: context.tr('vehicles'),
            subtitle: context.trFormat('vehicle_count', {
              'count': widget.session.vehicles.length,
            }),
          ),
          const SizedBox(height: 20),
          TextField(
            onChanged: (value) => setState(() => query = value),
            decoration: InputDecoration(
              hintText: context.tr('search_vehicle'),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<VehicleFilter>(
            segments: [
              ButtonSegment(
                value: VehicleFilter.all,
                label: Text(context.tr('all')),
              ),
              ButtonSegment(
                value: VehicleFilter.online,
                label: Text(context.tr('online')),
              ),
              ButtonSegment(
                value: VehicleFilter.offline,
                label: Text(context.tr('offline')),
              ),
            ],
            selected: {filter},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                setState(() => filter = selection.first),
          ),
          const SizedBox(height: 18),
          if (vehicles.isEmpty)
            SectionPanel(
              child: EmptyState(
                icon: Icons.search_off,
                message: context.tr('no_search_result'),
              ),
            )
          else
            ...vehicles.map(
              (vehicle) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SectionPanel(
                  child: VehicleRow(
                    vehicle: vehicle,
                    onTap: () => _showVehicle(context, vehicle),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showVehicle(BuildContext context, VehicleData vehicle) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(vehicle.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(vehicle.registration),
              const Divider(height: 30),
              _DetailLine(
                label: context.tr('status'),
                value: vehicle.isOnline
                    ? context.tr('online')
                    : context.tr('offline'),
              ),
              _DetailLine(
                label: context.tr('speed'),
                value: '${vehicle.speed} km/h',
              ),
              if (vehicle.address?.isNotEmpty == true)
                _DetailLine(
                  label: context.tr('last_position'),
                  value: vehicle.address!,
                ),
              if (vehicle.lastSignalAt != null)
                _DetailLine(
                  label: context.tr('last_signal'),
                  value: vehicle.lastSignalAt!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppTheme.muted)),
          ),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
