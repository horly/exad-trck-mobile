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
    this.showHeader = true,
  });

  final SessionController session;
  final ValueChanged<VehicleData>? onOpenMap;
  final VehicleFilter requestedFilter;
  final int filterRequestId;
  final bool showHeader;

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  String query = '';
  late VehicleFilter filter;
  final Set<String> _collapsedFleetKeys = {};

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

  List<_FleetVehicleGroup> _groupedVehicles(List<VehicleData> vehicles) {
    final groups = <String, _FleetVehicleGroup>{};

    for (final vehicle in vehicles) {
      final fleet = vehicle.fleet;
      final key = fleet == null ? 'unassigned' : 'fleet-${fleet.id}';
      groups.putIfAbsent(
        key,
        () => _FleetVehicleGroup(
          key: key,
          name: fleet?.name ?? context.tr('unassigned'),
          vehicles: [],
        ),
      );
      groups[key]!.vehicles.add(vehicle);
    }

    return groups.values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = filteredVehicles;
    final fleetGroups = _groupedVehicles(vehicles);
    return RefreshIndicator(
      onRefresh: widget.session.refreshWorkspace,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          if (widget.showHeader) ...[
            ScreenTitle(
              title: context.tr('vehicles'),
              subtitle: context.trFormat('vehicle_count', {
                'count': widget.session.vehicles.length,
              }),
            ),
            const SizedBox(height: 20),
          ],
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
            ...fleetGroups.map(
              (group) => _FleetVehicleGroupPanel(
                group: group,
                collapsed:
                    query.trim().isEmpty &&
                    _collapsedFleetKeys.contains(group.key),
                onToggle: () => setState(() {
                  if (!_collapsedFleetKeys.add(group.key)) {
                    _collapsedFleetKeys.remove(group.key);
                  }
                }),
                onOpenMap: widget.onOpenMap,
              ),
            ),
        ],
      ),
    );
  }
}

class _FleetVehicleGroup {
  const _FleetVehicleGroup({
    required this.key,
    required this.name,
    required this.vehicles,
  });

  final String key;
  final String name;
  final List<VehicleData> vehicles;
}

class _FleetVehicleGroupPanel extends StatelessWidget {
  const _FleetVehicleGroupPanel({
    required this.group,
    required this.collapsed,
    required this.onToggle,
    required this.onOpenMap,
  });

  final _FleetVehicleGroup group;
  final bool collapsed;
  final VoidCallback onToggle;
  final ValueChanged<VehicleData>? onOpenMap;

  @override
  Widget build(BuildContext context) {
    final onlineCount = group.vehicles
        .where((vehicle) => vehicle.isOnline)
        .length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Semantics(
              button: true,
              expanded: !collapsed,
              label: context.trFormat(
                collapsed ? 'expand_fleet' : 'collapse_fleet',
                {'name': group.name},
              ),
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.corporate_fare_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '${group.name} (${group.vehicles.length})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F8F0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$onlineCount/${group.vehicles.length}',
                          style: const TextStyle(
                            color: Color(0xFF087A58),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: collapsed ? -.25 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(Icons.keyboard_arrow_down, size: 21),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: collapsed
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        Divider(
                          height: 1,
                          color: Theme.of(context).dividerColor,
                        ),
                        ...group.vehicles.map(
                          (vehicle) => Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                            child: CorporateVehicleRow(
                              vehicle: vehicle,
                              onTap: onOpenMap == null
                                  ? null
                                  : () => onOpenMap!(vehicle),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
