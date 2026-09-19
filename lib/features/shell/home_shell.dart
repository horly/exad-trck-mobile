import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';
import '../../core/notifications/notification_controller.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/theme_controller.dart';
import '../alerts/alerts_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/superadmin_dashboard_screen.dart';
import '../map/map_screen.dart';
import '../more/more_screen.dart';
import '../notifications/notifications_screen.dart';
import '../vehicles/vehicles_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.session,
    required this.localeController,
    required this.themeController,
    required this.notifications,
  });

  final SessionController session;
  final LocaleController localeController;
  final ThemeController themeController;
  final NotificationController notifications;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const workspaceRefreshInterval = Duration(seconds: 10);

  final GlobalKey<NavigatorState> _contentNavigatorKey =
      GlobalKey<NavigatorState>();
  int selectedIndex = 0;
  int mapFocusRequestId = 0;
  VehicleData? mapFocusVehicle;
  Timer? workspaceRefreshTimer;
  StreamSubscription<NotificationOpenRequest>? notificationOpenSubscription;
  AppLifecycleState? appLifecycleState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appLifecycleState = WidgetsBinding.instance.lifecycleState;
    _startWorkspaceRefresh();
    unawaited(widget.notifications.attachSession(widget.session));
    notificationOpenSubscription = widget.notifications.openRequests.listen(
      _handleNotificationOpen,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pending = widget.notifications.takePendingOpenRequest();
      if (pending != null) _openNotifications(pending);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _startWorkspaceRefresh(refreshNow: true);
      unawaited(widget.notifications.attachSession(widget.session));
    } else {
      workspaceRefreshTimer?.cancel();
    }
  }

  @override
  void dispose() {
    workspaceRefreshTimer?.cancel();
    unawaited(notificationOpenSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canViewMap = widget.session.user?.hasPermission('map_view') == true;
    final superadmin = widget.session.user?.isSuperadmin == true;
    final dashboardDestination = _Destination(
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
    );
    final mapDestination = _Destination(
      label: context.tr('map'),
      icon: Icons.map_outlined,
      selectedIcon: Icons.map,
      builder: () => MapScreen(
        session: widget.session,
        active: selectedIndex == (superadmin ? 1 : 0),
        focusVehicle: mapFocusVehicle,
        focusRequestId: mapFocusRequestId,
      ),
    );
    final moreDestination = _Destination(
      label: context.tr('more'),
      icon: Icons.more_horiz,
      selectedIcon: Icons.more_horiz,
      builder: () => MoreScreen(
        session: widget.session,
        localeController: widget.localeController,
        themeController: widget.themeController,
        notifications: widget.notifications,
      ),
    );
    final destinations = superadmin
        ? <_Destination>[
            dashboardDestination,
            if (canViewMap) mapDestination,
            moreDestination,
          ]
        : <_Destination>[
            if (canViewMap) mapDestination,
            dashboardDestination,
            moreDestination,
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
              child: Navigator(
                key: _contentNavigatorKey,
                pages: [
                  MaterialPage<void>(
                    key: const ValueKey('authenticated-shell-content'),
                    child: IndexedStack(
                      index: selectedIndex,
                      children: destinations
                          .map((destination) => destination.builder())
                          .toList(),
                    ),
                  ),
                ],
                onDidRemovePage: (_) {},
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          systemNavigationBarColor: Theme.of(context).colorScheme.primary,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              ThemeData.estimateBrightnessForColor(
                    Theme.of(context).colorScheme.primary,
                  ) ==
                  Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            _contentNavigatorKey.currentState?.popUntil(
              (route) => route.isFirst,
            );
            final dashboardIndex = _dashboardIndex();
            final returningToDashboard =
                index == dashboardIndex && selectedIndex != dashboardIndex;
            setState(() => selectedIndex = index);
            if (returningToDashboard) unawaited(_refreshWorkspaceSilently());
          },
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

  void _openVehicleOnMap(VehicleData vehicle) {
    final superadmin = widget.session.user?.isSuperadmin == true;
    setState(() {
      mapFocusVehicle = vehicle;
      mapFocusRequestId++;
      selectedIndex = superadmin ? 1 : 0;
    });
  }

  void _openMapOverview() {
    if (widget.session.user?.hasPermission('map_view') != true) return;
    final superadmin = widget.session.user?.isSuperadmin == true;
    setState(() {
      mapFocusVehicle = null;
      mapFocusRequestId++;
      selectedIndex = superadmin ? 1 : 0;
    });
  }

  void _openVehicles(VehicleFilter filter) {
    final canViewMap = widget.session.user?.hasPermission('map_view') == true;
    final title = context.tr('vehicles');
    _contentNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (routeContext) => _StandaloneSection(
          title: title,
          child: VehiclesScreen(
            session: widget.session,
            showHeader: false,
            requestedFilter: filter,
            onOpenMap: !canViewMap
                ? null
                : (vehicle) {
                    Navigator.of(routeContext).pop();
                    _openVehicleOnMap(vehicle);
                  },
          ),
        ),
      ),
    );
  }

  void _openAlerts() {
    final title = context.tr('alerts');
    _contentNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => _StandaloneSection(
          title: title,
          child: AlertsScreen(session: widget.session, showHeader: false),
        ),
      ),
    );
  }

  void _handleNotificationOpen(NotificationOpenRequest request) {
    if (!mounted) return;
    widget.notifications.takePendingOpenRequest();
    _openNotifications(request);
  }

  void _openNotifications(NotificationOpenRequest request) {
    final navigator = _contentNavigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openNotifications(request);
      });
      return;
    }
    navigator.popUntil((route) => route.isFirst);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => _StandaloneSection(
          title: context.tr('notifications'),
          child: NotificationsScreen(
            session: widget.session,
            initialCategory: request.category,
            highlightedId: request.id,
          ),
        ),
      ),
    );
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
    if (!mounted ||
        !lifecycleAllowsRefresh ||
        selectedIndex != _dashboardIndex()) {
      return;
    }
    await widget.session.refreshWorkspace(silent: true);
  }

  int _dashboardIndex() {
    if (widget.session.user?.isSuperadmin == true) return 0;
    return widget.session.user?.hasPermission('map_view') == true ? 1 : 0;
  }
}

class _StandaloneSection extends StatelessWidget {
  const _StandaloneSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: child),
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
