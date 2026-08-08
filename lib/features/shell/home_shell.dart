import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/theme_controller.dart';
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
    required this.themeController,
  });

  final SessionController session;
  final LocaleController localeController;
  final ThemeController themeController;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const workspaceRefreshInterval = Duration(seconds: 10);

  int selectedIndex = 0;
  int mapFocusRequestId = 0;
  VehicleData? mapFocusVehicle;
  int vehicleFilterRequestId = 0;
  VehicleFilter requestedVehicleFilter = VehicleFilter.all;
  Timer? workspaceRefreshTimer;
  AppLifecycleState? appLifecycleState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appLifecycleState = WidgetsBinding.instance.lifecycleState;
    _startWorkspaceRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _startWorkspaceRefresh(refreshNow: true);
    } else {
      workspaceRefreshTimer?.cancel();
    }
  }

  @override
  void dispose() {
    workspaceRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canViewMap = widget.session.user?.hasPermission('map_view') == true;
    final superadmin = widget.session.user?.isSuperadmin == true;
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
                onOpenVehicles: () => _openVehicles(VehicleFilter.all),
                onOpenOnlineVehicles: () => _openVehicles(VehicleFilter.online),
                onOpenAlerts: _openAlerts,
                onOpenVehicleMap: canViewMap ? _openVehicleOnMap : null,
              )
            : DashboardScreen(
                session: widget.session,
                onOpenVehicles: () => _openVehicles(VehicleFilter.all),
                onOpenOnlineVehicles: () => _openVehicles(VehicleFilter.online),
                onOpenMap: canViewMap ? _openMapOverview : null,
                onOpenAlerts: _openAlerts,
                onOpenVehicleMap: canViewMap ? _openVehicleOnMap : null,
              ),
      ),
      if (canViewMap)
        _Destination(
          label: context.tr('map'),
          icon: Icons.map_outlined,
          selectedIcon: Icons.map,
          builder: () => MapScreen(
            session: widget.session,
            active: selectedIndex == 1,
            focusVehicle: mapFocusVehicle,
            focusRequestId: mapFocusRequestId,
          ),
        ),
      _Destination(
        label: context.tr('vehicles'),
        icon: Icons.directions_car_outlined,
        selectedIcon: Icons.directions_car,
        builder: () => VehiclesScreen(
          session: widget.session,
          onOpenMap: canViewMap ? _openVehicleOnMap : null,
          requestedFilter: requestedVehicleFilter,
          filterRequestId: vehicleFilterRequestId,
        ),
      ),
      _Destination(
        label: context.tr('alerts'),
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
        badgeCount: widget.session.dashboard.newAlerts,
        builder: () => AlertsScreen(session: widget.session),
      ),
      _Destination(
        label: context.tr('more'),
        icon: Icons.more_horiz,
        selectedIcon: Icons.more_horiz,
        builder: () => MoreScreen(
          session: widget.session,
          localeController: widget.localeController,
          themeController: widget.themeController,
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
          onDestinationSelected: (index) {
            final returningToDashboard = index == 0 && selectedIndex != 0;
            setState(() => selectedIndex = index);
            if (returningToDashboard) unawaited(_refreshWorkspaceSilently());
          },
          destinations: destinations
              .map(
                (destination) => NavigationDestination(
                  icon: _DestinationIcon(
                    icon: destination.icon,
                    badgeCount: destination.badgeCount,
                  ),
                  selectedIcon: _DestinationIcon(
                    icon: destination.selectedIcon,
                    badgeCount: destination.badgeCount,
                  ),
                  label: destination.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _openVehicleOnMap(VehicleData vehicle) {
    setState(() {
      mapFocusVehicle = vehicle;
      mapFocusRequestId++;
      selectedIndex = 1;
    });
  }

  void _openMapOverview() {
    if (widget.session.user?.hasPermission('map_view') != true) return;
    setState(() {
      mapFocusVehicle = null;
      mapFocusRequestId++;
      selectedIndex = 1;
    });
  }

  void _openVehicles(VehicleFilter filter) {
    final canViewMap = widget.session.user?.hasPermission('map_view') == true;
    setState(() {
      requestedVehicleFilter = filter;
      vehicleFilterRequestId++;
      selectedIndex = canViewMap ? 2 : 1;
    });
  }

  void _openAlerts() {
    final canViewMap = widget.session.user?.hasPermission('map_view') == true;
    setState(() => selectedIndex = canViewMap ? 3 : 2);
  }

  void _startWorkspaceRefresh({bool refreshNow = false}) {
    workspaceRefreshTimer?.cancel();
    if (refreshNow) unawaited(_refreshWorkspaceSilently());
    workspaceRefreshTimer = Timer.periodic(
      workspaceRefreshInterval,
      (_) => unawaited(_refreshWorkspaceSilently()),
    );
  }

  Future<void> _refreshWorkspaceSilently() async {
    final lifecycleAllowsRefresh =
        appLifecycleState == null ||
        appLifecycleState == AppLifecycleState.resumed;
    if (!mounted || !lifecycleAllowsRefresh || selectedIndex != 0) return;
    await widget.session.refreshWorkspace(silent: true);
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() builder;
  final int badgeCount;
}

class _DestinationIcon extends StatelessWidget {
  const _DestinationIcon({required this.icon, required this.badgeCount});

  final IconData icon;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final countLabel = badgeCount > 99 ? '99+' : '$badgeCount';
    return Badge(
      isLabelVisible: badgeCount > 0,
      label: Text(
        countLabel,
        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800),
      ),
      backgroundColor: const Color(0xFFEF4444),
      textColor: Colors.white,
      offset: const Offset(8, -6),
      child: Icon(icon),
    );
  }
}
