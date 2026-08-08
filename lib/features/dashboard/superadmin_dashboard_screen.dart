import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/exad_logo.dart';
import '../../shared/widgets/ui_components.dart';

class SuperadminDashboardScreen extends StatelessWidget {
  const SuperadminDashboardScreen({
    super.key,
    required this.session,
    required this.onOpenVehicles,
    required this.onOpenOnlineVehicles,
    required this.onOpenAlerts,
    required this.onOpenVehicleMap,
  });

  final SessionController session;
  final VoidCallback onOpenVehicles;
  final VoidCallback onOpenOnlineVehicles;
  final VoidCallback onOpenAlerts;
  final ValueChanged<VehicleData>? onOpenVehicleMap;

  @override
  Widget build(BuildContext context) {
    final data = session.dashboard;
    final fleetGroups = data.fleetDistribution;
    final fleetDistributionKey = GlobalKey();
    return RefreshIndicator(
      onRefresh: session.refreshWorkspace,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1746),
              border: Border.all(color: const Color(0xFF263A79)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ExadLogo(height: 38, inverse: true),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D4ED8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        context.tr('superadmin_space'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  context.tr('supervision'),
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 5),
                Text(
                  context.tr('global_overview'),
                  style: const TextStyle(
                    color: Color(0xFFB7C6EB),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.12,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              MetricTile(
                label: context.tr('fleets'),
                value: data.totalFleets,
                icon: Icons.local_shipping_outlined,
                color: const Color(0xFF1D4ED8),
                onTap: () {
                  final target = fleetDistributionKey.currentContext;
                  if (target != null) {
                    Scrollable.ensureVisible(
                      target,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
              MetricTile(
                label: context.tr('vehicles'),
                value: data.totalVehicles,
                icon: Icons.directions_car_filled_outlined,
                color: session.branding.accent,
                onTap: onOpenVehicles,
              ),
              MetricTile(
                label: context.tr('online'),
                value: data.onlineVehicles,
                icon: Icons.signal_cellular_alt,
                color: AppTheme.success,
                onTap: onOpenOnlineVehicles,
              ),
              MetricTile(
                label: context.tr('attention'),
                value: data.attentionVehicles,
                icon: Icons.warning_amber_rounded,
                color: AppTheme.danger,
                onTap: onOpenAlerts,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            key: fleetDistributionKey,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('global_fleet_distribution'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: context.tr('view_all'),
                  onPressed: onOpenVehicles,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SectionPanel(
            child: fleetGroups.isEmpty
                ? EmptyState(
                    icon: Icons.local_shipping_outlined,
                    message: context.tr('no_vehicle'),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < fleetGroups.length; i++) ...[
                        _FleetLine(group: fleetGroups[i]),
                        if (i < fleetGroups.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('active_fleets'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          Text(
            context.tr('platform_activity'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (data.vehicles.isEmpty)
            SectionPanel(
              child: EmptyState(
                icon: Icons.directions_car_outlined,
                message: context.tr('no_vehicle'),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < data.vehicles.length; i++) ...[
                  CorporateVehicleRow(
                    vehicle: data.vehicles[i],
                    onTap: onOpenVehicleMap == null
                        ? null
                        : () => onOpenVehicleMap!(data.vehicles[i]),
                  ),
                  if (i < data.vehicles.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _FleetLine extends StatelessWidget {
  const _FleetLine({required this.group});

  final FleetSummary group;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1D4ED8).withValues(alpha: .1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              group.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${group.totalVehicles}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '${group.onlineVehicles} ${context.tr('online').toLowerCase()}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
