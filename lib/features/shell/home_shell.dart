import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/session/session_controller.dart';
import '../alerts/alerts_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/superadmin_dashboard_screen.dart';
import '../map/map_screen.dart';
import '../more/more_screen.dart';
import '../vehicles/vehicles_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.session,
    required this.localeController,
  });

  final SessionController session;
  final LocaleController localeController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final canViewMap = widget.session.user?.hasPermission('map_view') == true;
    final superadmin = widget.session.user?.isSuperadmin == true;
    final vehiclesIndex = canViewMap ? 2 : 1;
    final destinations = <_Destination>[
      _Destination(
        label: context.tr(superadmin ? 'supervision' : 'home'),
        icon: superadmin
            ? Icons.admin_panel_settings_outlined
            : Icons.dashboard_outlined,
        selectedIcon: superadmin ? Icons.admin_panel_settings : Icons.dashboard,
        builder: () => superadmin
            ? SuperadminDashboardScreen(
                session: widget.session,
                onOpenVehicles: () =>
                    setState(() => selectedIndex = vehiclesIndex),
              )
            : DashboardScreen(
                session: widget.session,
                onOpenVehicles: () =>
                    setState(() => selectedIndex = vehiclesIndex),
              ),
      ),
      if (canViewMap)
        _Destination(
          label: context.tr('map'),
          icon: Icons.map_outlined,
          selectedIcon: Icons.map,
          builder: () =>
              MapScreen(session: widget.session, active: selectedIndex == 1),
        ),
      _Destination(
        label: context.tr('vehicles'),
        icon: Icons.directions_car_outlined,
        selectedIcon: Icons.directions_car,
        builder: () => VehiclesScreen(session: widget.session),
      ),
      _Destination(
        label: context.tr('alerts'),
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
        builder: () => AlertsScreen(session: widget.session),
      ),
      _Destination(
        label: context.tr('more'),
        icon: Icons.more_horiz,
        selectedIcon: Icons.more_horiz,
        builder: () => MoreScreen(
          session: widget.session,
          localeController: widget.localeController,
        ),
      ),
    ];
    if (selectedIndex >= destinations.length) selectedIndex = 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (widget.session.workspaceLoading)
              LinearProgressIndicator(
                minHeight: 2,
                color: widget.session.branding.secondary,
              ),
            Expanded(
              child: IndexedStack(
                index: selectedIndex,
                children: destinations
                    .map((destination) => destination.builder())
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: widget.session.branding.primary,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarContrastEnforced: false,
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) =>
              setState(() => selectedIndex = index),
          destinations: destinations
              .map(
                (destination) => NavigationDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: destination.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() builder;
}
