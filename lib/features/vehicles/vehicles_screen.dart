import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';
import '../../core/session/session_controller.dart';
import '../../shared/widgets/ui_components.dart';

enum VehicleFilter { all, online, offline }

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({
    super.key,
    required this.session,
    required this.onOpenMap,
    this.requestedFilter = VehicleFilter.all,
    this.filterRequestId = 0,
  });

  final SessionController session;
  final ValueChanged<VehicleData>? onOpenMap;
  final VehicleFilter requestedFilter;
  final int filterRequestId;

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  String query = '';
  late VehicleFilter filter;

  @override
  void initState() {
    super.initState();
    filter = widget.requestedFilter;
  }

  @override
  void didUpdateWidget(covariant VehiclesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterRequestId != widget.filterRequestId) {
      filter = widget.requestedFilter;
    }
  }

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
                padding: const EdgeInsets.only(bottom: 8),
                child: CorporateVehicleRow(
                  vehicle: vehicle,
                  onTap: widget.onOpenMap == null
                      ? null
                      : () => widget.onOpenMap!(vehicle),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
