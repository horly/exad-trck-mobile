import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui_components.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.session,
    required this.onOpenVehicles,
  });

  final SessionController session;
  final VoidCallback onOpenVehicles;

  @override
  Widget build(BuildContext context) {
    final data = session.dashboard;
    final user = session.user;
    return RefreshIndicator(
      onRefresh: session.refreshWorkspace,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            sliver: SliverList.list(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('fleet_space'),
                        style: TextStyle(
                          color: session.branding.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 9),
                      ScreenTitle(
                        title: context.trFormat('hello', {
                          'name': user?.name.split(' ').first ?? '',
                        }),
                        subtitle: user?.fleet == null
                            ? context.tr('fleet_overview')
                            : '${user!.fleet!.name} · ${user.fleet!.code}',
                        trailing: CircleAvatar(
                          backgroundColor: session.branding.primary,
                          foregroundColor: Colors.white,
                          child: Text(user?.initials ?? 'U'),
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
                      label: context.tr('vehicles'),
                      value: data.totalVehicles,
                      icon: Icons.directions_car_filled_outlined,
                      color: session.branding.secondary,
                    ),
                    MetricTile(
                      label: context.tr('online'),
                      value: data.onlineVehicles,
                      icon: Icons.signal_cellular_alt,
                      color: AppTheme.success,
                    ),
                    MetricTile(
                      label: context.tr('moving'),
                      value: data.movingVehicles,
                      icon: Icons.route_outlined,
                      color: session.branding.accent,
                    ),
                    MetricTile(
                      label: context.tr('attention'),
                      value: data.attentionVehicles,
                      icon: Icons.warning_amber_rounded,
                      color: AppTheme.danger,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SectionHeading(
                  title: context.tr('fleet_activity'),
                  onTap: onOpenVehicles,
                ),
                const SizedBox(height: 10),
                SectionPanel(
                  child: data.vehicles.isEmpty
                      ? EmptyState(
                          icon: Icons.directions_car_outlined,
                          message: context.tr('no_vehicle'),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < data.vehicles.length; i++) ...[
                              VehicleRow(
                                vehicle: data.vehicles[i],
                                onTap: onOpenVehicles,
                              ),
                              if (i < data.vehicles.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 22),
                _SectionHeading(title: context.tr('recent_alerts')),
                const SizedBox(height: 10),
                SectionPanel(
                  child: data.alerts.isEmpty
                      ? EmptyState(
                          icon: Icons.notifications_none,
                          message: context.tr('no_alert'),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < data.alerts.length; i++) ...[
                              AlertRow(alert: data.alerts[i]),
                              if (i < data.alerts.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.onTap});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (onTap != null)
          IconButton(
            tooltip: context.tr('view_all'),
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward),
          ),
      ],
    );
  }
}
