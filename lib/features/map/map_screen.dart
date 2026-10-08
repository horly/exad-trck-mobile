import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';
import '../../core/session/session_controller.dart';
import '../../shared/widgets/fleet_status_icon.dart';
import '../../shared/widgets/ui_components.dart';
import 'map_vehicle_sheets.dart';
import 'selected_vehicle_strip.dart';
import '../../shared/widgets/fuel_level_badge.dart';
import '../../shared/widgets/vehicle_marker_style.dart';
import 'live_position_motion.dart';
import 'trip_history_panel.dart';

const _darkMapStyle = '''[
  {"elementType":"geometry","stylers":[{"color":"#172033"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#A7B3C8"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#172033"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#36445D"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#1E293B"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#16352F"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#29364B"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#111827"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3A4A65"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#243044"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#081426"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#64748B"}]}
]''';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.session,
    required this.active,
    this.focusVehicle,
    this.focusRequestId = 0,
  });

  final SessionController session;
  final bool active;
  final VehicleData? focusVehicle;
  final int focusRequestId;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  static const liveRefreshInterval = Duration(seconds: 10);
  static const selectedTelemetryRefreshInterval = Duration(minutes: 1);
  static const markerAnimationDuration = Duration(seconds: 5);
  static const initialStreetZoom = 17.5;
  static const selectedVehicleZoom = 18.0;

  final searchController = TextEditingController();
  GoogleMapController? mapController;
  VehicleData? selectedVehicle;
  VehicleDetailData? selectedVehicleDetails;
  VehicleData? historyVehicle;
  bool historyCollapsed = false;
  final historyPanelKey = GlobalKey();
  double? historyPanelHeight;
  int historyLayoutGeneration = 0;
  List<LatLng> historyPoints = [];
  List<VehicleTripData> historyTrips = [];
  final Map<String, Marker> historyPins = {};
  int historyGeneration = 0;
  Marker? historyReplay;
  List<VehicleData> liveVehicles = const [];
  final Map<int, LatLng> displayedPositions = {};
  final Map<int, _VehicleMotion> motions = {};
  final Map<_VehicleMarkerState, BitmapDescriptor> markerIcons = {};
  Timer? refreshTimer;
  Timer? selectedTelemetryTimer;
  Timer? animationTimer;
  String query = '';
  String statusFilter = 'all';
  final Set<String> _collapsedMapFleetKeys = {};
  bool panelVisible = false;
  bool myLocationEnabled = false;
  bool autoRefresh = true;
  bool refreshing = false;
  DateTime? lastUpdatedAt;
  DateTime? lastCameraFollowAt;
  int handledFocusRequestId = 0;
  bool _hasFreshSnapshot = false;
  bool _appResumed = true;
  bool _resumeRefreshPending = false;
  int _liveGeneration = 0;
  final Set<int> _snapOnNextUpdate = {};

  List<VehicleData> get positionedVehicles => liveVehicles
      .where((vehicle) => vehicle.latitude != null && vehicle.longitude != null)
      .toList();

  List<VehicleData> get filteredVehicles {
    final normalized = query.trim().toLowerCase();
    return positionedVehicles.where((vehicle) {
      final matchesSearch =
          normalized.isEmpty ||
          vehicle.name.toLowerCase().contains(normalized) ||
          vehicle.registration.toLowerCase().contains(normalized);
      final matchesStatus = switch (statusFilter) {
        'online' => vehicle.isOnline,
        'moving' => vehicle.isMoving,
        'parking' => vehicle.isParking,
        'offline' => !vehicle.isOnline,
        _ => true,
      };
      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    liveVehicles = List<VehicleData>.of(widget.session.mapVehicles);
    _seedDisplayedPositions(liveVehicles);
    unawaited(_loadMarkerIcons());
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startLiveRefresh();
        _handleFocusRequest();
      });
    }
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        _startLiveRefresh();
        _startSelectedTelemetryRefresh();
      } else {
        _resetLiveAnimation();
        refreshTimer?.cancel();
        selectedTelemetryTimer?.cancel();
      }
    }
    if (widget.active && oldWidget.focusRequestId != widget.focusRequestId) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _handleFocusRequest(),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed && widget.active) {
      _startLiveRefresh();
      _startSelectedTelemetryRefresh();
      return;
    }
    _resetLiveAnimation();
    refreshTimer?.cancel();
    selectedTelemetryTimer?.cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refreshTimer?.cancel();
    selectedTelemetryTimer?.cancel();
    animationTimer?.cancel();
    searchController.dispose();
    mapController?.dispose();
    super.dispose();
  }

  void _resetLiveAnimation() {
    _liveGeneration++;
    _hasFreshSnapshot = false;
    animationTimer?.cancel();
    motions.clear();
    _seedDisplayedPositions(liveVehicles);
    lastCameraFollowAt = null;
  }

  void _startLiveRefresh() {
    _resetLiveAnimation();
    _resumeRefreshPending = refreshing;
    refreshTimer?.cancel();
    if (!widget.active || !autoRefresh || !_appResumed) return;
    unawaited(_refreshLive());
    refreshTimer = Timer.periodic(
      liveRefreshInterval,
      (_) => unawaited(_refreshLive()),
    );
  }

  void _startSelectedTelemetryRefresh() {
    selectedTelemetryTimer?.cancel();
    final vehicle = selectedVehicle;
    if (!widget.active || vehicle == null) return;

    unawaited(_loadSelectedVehicleTelemetry(vehicle.id));
    selectedTelemetryTimer = Timer.periodic(selectedTelemetryRefreshInterval, (
      _,
    ) {
      final current = selectedVehicle;
      if (widget.active && current != null && current.hasAvailableGps) {
        unawaited(_loadSelectedVehicleTelemetry(current.id));
      }
    });
  }

  Future<void> _refreshLive({bool fit = false, bool showError = false}) async {
    if (refreshing || !mounted || !widget.active || !_appResumed) return;
    final generation = _liveGeneration;
    setState(() => refreshing = true);
    try {
      final snapshot = await widget.session.mapSnapshot();
      if (!mounted ||
          generation != _liveGeneration ||
          !widget.active ||
          !_appResumed) {
        return;
      }
      _applySnapshot(snapshot);
      if (fit) await _fitVehicles(positionedVehicles);
    } catch (_) {
      if (!mounted || generation != _liveGeneration) return;
      _resetLiveAnimation();
      if (!showError) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('map_refresh_failed'))));
    } finally {
      if (mounted) {
        setState(() => refreshing = false);
        if (generation != _liveGeneration &&
            widget.active &&
            _appResumed &&
            autoRefresh) {
          // A request begun before backgrounding must never seed a resumed animation.
          // Let the regular refresh timer retry failures; queue only a lifecycle change.
          if (_resumeRefreshPending) {
            _resumeRefreshPending = false;
            unawaited(_refreshLive());
          }
        }
      }
    }
  }

  void _applySnapshot(List<VehicleData> snapshot) {
    final now = DateTime.now();
    final continuous =
        _hasFreshSnapshot &&
        widget.active &&
        _appResumed &&
        lastUpdatedAt != null &&
        now.difference(lastUpdatedAt!) <= const Duration(seconds: 30);
    final previous = {for (final vehicle in liveVehicles) vehicle.id: vehicle};
    var selectedSnapped = false;
    final nextIds = snapshot.map((vehicle) => vehicle.id).toSet();
    displayedPositions.removeWhere((id, _) => !nextIds.contains(id));
    motions.removeWhere((id, _) => !nextIds.contains(id));
    _snapOnNextUpdate.retainAll(nextIds);

    for (final vehicle in snapshot) {
      if (vehicle.latitude == null || vehicle.longitude == null) continue;
      final target = LatLng(vehicle.latitude!, vehicle.longitude!);
      final current = displayedPositions[vehicle.id] ?? target;
      final snap = _snapOnNextUpdate.remove(vehicle.id);
      if (!snap &&
          canAnimateLivePosition(
            continuous: continuous,
            previous: previous[vehicle.id],
            next: vehicle,
            current: GeoCoordinateData(current.latitude, current.longitude),
            now: now,
          )) {
        motions[vehicle.id] = _VehicleMotion(
          path: _motionPath(vehicle, current, target),
          startedAt: DateTime.now(),
          duration: markerAnimationDuration,
        );
      } else {
        displayedPositions[vehicle.id] = target;
        motions.remove(vehicle.id);
        if (selectedVehicle?.id == vehicle.id &&
            (snap || !continuous || !_samePosition(current, target))) {
          selectedSnapped = true;
        }
      }
    }

    final selectedId = selectedVehicle?.id;
    setState(() {
      liveVehicles = List<VehicleData>.of(snapshot);
      selectedVehicle = selectedId == null
          ? null
          : snapshot.where((vehicle) => vehicle.id == selectedId).firstOrNull;
      lastUpdatedAt = now;
      _hasFreshSnapshot = true;
    });
    if (selectedSnapped &&
        selectedId != null &&
        historyVehicle == null &&
        mapController != null) {
      final position = displayedPositions[selectedId];
      if (position != null) {
        unawaited(mapController!.moveCamera(CameraUpdate.newLatLng(position)));
      }
    }
    _ensureAnimationTicker();
    _handleFocusRequest();
  }

  void _seedDisplayedPositions(List<VehicleData> vehicles) {
    for (final vehicle in vehicles) {
      if (vehicle.latitude == null || vehicle.longitude == null) continue;
      displayedPositions[vehicle.id] = LatLng(
        vehicle.latitude!,
        vehicle.longitude!,
      );
    }
  }

  Future<void> _loadMarkerIcons() async {
    final icons = <_VehicleMarkerState, BitmapDescriptor>{};
    for (final state in _VehicleMarkerState.values) {
      icons[state] = await _buildMarkerIcon(state);
    }
    if (!mounted) return;
    setState(() {
      markerIcons
        ..clear()
        ..addAll(icons);
    });
  }

  Future<BitmapDescriptor> _buildMarkerIcon(_VehicleMarkerState state) async {
    const canvasSize = 96.0;
    const center = Offset(canvasSize / 2, canvasSize / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final color = _markerColor(state);

    if (state == _VehicleMarkerState.moving) {
      final arrow = Path()
        ..moveTo(center.dx, 9)
        ..lineTo(17, 84)
        ..lineTo(center.dx, 66)
        ..lineTo(79, 84)
        ..close();
      canvas.drawShadow(arrow, const Color(0x660F234B), 8, true);
      canvas.drawPath(
        arrow,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(arrow, Paint()..color = color);
    } else if (state == _VehicleMarkerState.stationaryRunning) {
      final outer = RRect.fromRectAndRadius(
        const Rect.fromLTWH(15, 15, 66, 66),
        const Radius.circular(14),
      );
      final inner = RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 20, 56, 56),
        const Radius.circular(10),
      );
      canvas.drawShadow(
        Path()..addRRect(outer),
        const Color(0x660F234B),
        8,
        true,
      );
      canvas.drawRRect(outer, Paint()..color = Colors.white);
      canvas.drawRRect(inner, Paint()..color = color);
      final pausePaint = Paint()..color = Colors.white;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(34, 31, 8, 34),
          const Radius.circular(3),
        ),
        pausePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(54, 31, 8, 34),
          const Radius.circular(3),
        ),
        pausePaint,
      );
    } else {
      final outer = Path()..addOval(const Rect.fromLTWH(13, 13, 70, 70));
      canvas.drawShadow(outer, const Color(0x660F234B), 8, true);
      canvas.drawCircle(center, 35, Paint()..color = Colors.white);
      canvas.drawCircle(center, 29, Paint()..color = color);
      if (state == _VehicleMarkerState.parking) {
        _drawMarkerText(canvas, 'P', fontSize: 34);
      } else {
        _drawMarkerIcon(canvas, Icons.directions_car_rounded, size: 34);
      }
    }

    final image = await recorder.endRecording().toImage(
      canvasSize.toInt(),
      canvasSize.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return BitmapDescriptor.bytes(
      Uint8List.view(bytes!.buffer),
      width: 38,
      height: 38,
    );
  }

  void _drawMarkerText(Canvas canvas, String text, {required double fontSize}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((96 - painter.width) / 2, (96 - painter.height) / 2),
    );
  }

  void _drawMarkerIcon(Canvas canvas, IconData icon, {required double size}) {
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset((96 - painter.width) / 2, (96 - painter.height) / 2),
    );
  }

  List<LatLng> _motionPath(VehicleData vehicle, LatLng current, LatLng target) {
    final serverPath = vehicle.trail
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    if (serverPath.length < 2) return [current, target];

    var closestIndex = 0;
    var closestDistance = double.infinity;
    for (var index = 0; index < serverPath.length; index++) {
      final distance = _distanceBetween(current, serverPath[index]);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = index;
      }
    }

    final path = <LatLng>[current];
    for (final point in serverPath.skip(closestIndex + 1)) {
      if (!_samePosition(path.last, point)) path.add(point);
    }
    if (!_samePosition(path.last, target)) path.add(target);
    return path.length > 1 ? path : [current, target];
  }

  void _ensureAnimationTicker() {
    if (!widget.active ||
        !_appResumed ||
        motions.isEmpty ||
        animationTimer?.isActive == true) {
      return;
    }
    animationTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || !widget.active || !_appResumed || motions.isEmpty) {
        animationTimer?.cancel();
        return;
      }

      final now = DateTime.now();
      final completed = <int>[];
      for (final entry in motions.entries) {
        final elapsed = now.difference(entry.value.startedAt);
        final linear =
            (elapsed.inMilliseconds / entry.value.duration.inMilliseconds)
                .clamp(0.0, 1.0);
        final progress = Curves.easeInOut.transform(linear);
        displayedPositions[entry.key] = _positionAlongPath(
          entry.value.path,
          progress,
        );
        if (linear >= 1) completed.add(entry.key);
      }
      for (final id in completed) {
        motions.remove(id);
      }
      final selectedId = selectedVehicle?.id;
      final selectedPosition = selectedId == null
          ? null
          : displayedPositions[selectedId];
      final shouldFollow =
          historyVehicle == null &&
          selectedPosition != null &&
          (lastCameraFollowAt == null ||
              now.difference(lastCameraFollowAt!) >=
                  const Duration(milliseconds: 250));
      final controller = mapController;
      if (shouldFollow && controller != null) {
        lastCameraFollowAt = now;
        unawaited(
          controller.moveCamera(CameraUpdate.newLatLng(selectedPosition)),
        );
      }
      setState(() {});
    });
  }

  LatLng _positionAlongPath(List<LatLng> path, double ratio) {
    if (path.length < 2) return path.first;
    final distances = <double>[];
    var totalDistance = 0.0;
    for (var index = 1; index < path.length; index++) {
      final distance = _distanceBetween(path[index - 1], path[index]);
      distances.add(distance);
      totalDistance += distance;
    }
    if (totalDistance == 0) return path.last;

    final targetDistance = totalDistance * ratio;
    var traversed = 0.0;
    for (var index = 0; index < distances.length; index++) {
      final segmentDistance = distances[index];
      if (traversed + segmentDistance >= targetDistance) {
        final segmentRatio = segmentDistance == 0
            ? 1.0
            : (targetDistance - traversed) / segmentDistance;
        final from = path[index];
        final to = path[index + 1];
        return LatLng(
          from.latitude + ((to.latitude - from.latitude) * segmentRatio),
          from.longitude + ((to.longitude - from.longitude) * segmentRatio),
        );
      }
      traversed += segmentDistance;
    }
    return path.last;
  }

  double _distanceBetween(LatLng first, LatLng second) {
    return Geolocator.distanceBetween(
      first.latitude,
      first.longitude,
      second.latitude,
      second.longitude,
    );
  }

  bool _samePosition(LatLng first, LatLng second) {
    return (first.latitude - second.latitude).abs() < 0.0000001 &&
        (first.longitude - second.longitude).abs() < 0.0000001;
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = positionedVehicles;
    if (vehicles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: SectionPanel(
          child: EmptyState(
            icon: Icons.location_off_outlined,
            message: context.tr('no_position'),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildMap(context, constraints, vehicles),
    );
  }

  Widget _buildMap(
    BuildContext context,
    BoxConstraints constraints,
    List<VehicleData> vehicles,
  ) {
    final platform = Theme.of(context).platform;
    final compact =
        platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        constraints.maxWidth < 720;
    final panelWidth = compact
        ? (constraints.maxWidth * .82).clamp(280.0, 360.0).toDouble()
        : 340.0;
    final historyWide =
        constraints.maxWidth >= 720 ||
        (constraints.maxWidth >= 600 &&
            constraints.maxWidth > constraints.maxHeight);
    // Keep the history header directly below the mobile toolbar/telemetry.
    final historyTop = compact
        ? (selectedVehicle == null ? 66.0 : 136.0)
        : 16.0;
    final historyAvailable = (constraints.maxHeight - historyTop - 12)
        .clamp(0.0, double.infinity)
        .toDouble();
    // Leave the lower map visible while the portrait history is expanded.
    final historyHeight = historyWide
        ? historyAvailable
        : (historyAvailable * .65)
              .clamp(historyAvailable.clamp(0.0, 280.0), historyAvailable)
              .toDouble();
    if (historyVehicle != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || historyVehicle == null) return;
        final height = historyPanelKey.currentContext?.size?.height;
        if (height != null && (height - (historyPanelHeight ?? 0)).abs() > .5) {
          setState(() => historyPanelHeight = height);
          _scheduleHistoryFit();
        }
      });
    }
    final historyWidth = historyWide ? 390.0 : constraints.maxWidth - 24;
    final selectedPanelLeft = panelVisible && !compact ? panelWidth + 32 : 16.0;

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
            style: Theme.of(context).brightness == Brightness.dark
                ? _darkMapStyle
                : null,
            initialCameraPosition: CameraPosition(
              target: LatLng(
                vehicles.first.latitude!,
                vehicles.first.longitude!,
              ),
              zoom: initialStreetZoom,
            ),
            padding: historyVehicle == null
                ? EdgeInsets.zero
                : historyWide
                ? EdgeInsets.only(left: historyWidth + 28)
                : EdgeInsets.only(
                    top:
                        historyTop +
                        (historyCollapsed
                            ? 70
                            : (historyPanelHeight ?? historyHeight)) +
                        8,
                  ),
            markers: _markers(vehicles),
            polylines: _polylines(),
            myLocationEnabled: myLocationEnabled,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
            onMapCreated: (controller) {
              mapController = controller;
              _handleFocusRequest();
            },
          ),
        ),
        if (compact && panelVisible)
          Positioned(
            left: panelWidth,
            right: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => panelVisible = false),
              child: ColoredBox(color: Colors.black.withValues(alpha: .18)),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          left: panelVisible ? (compact ? 0 : 16) : -panelWidth - 12,
          top: compact ? 0 : 16,
          bottom: compact ? 0 : 16,
          width: panelWidth,
          child: _VehicleMapPanel(
            compact: compact,
            allVehicles: liveVehicles,
            searchController: searchController,
            vehicles: filteredVehicles,
            collapsedFleetKeys: _collapsedMapFleetKeys,
            onToggleFleet: (key) => setState(() {
              if (!_collapsedMapFleetKeys.add(key)) {
                _collapsedMapFleetKeys.remove(key);
              }
            }),
            selectedVehicle: selectedVehicle,
            statusFilter: statusFilter,
            autoRefresh: autoRefresh,
            refreshing: refreshing,
            lastUpdatedAt: lastUpdatedAt,
            onRefresh: () => _refreshLive(showError: true),
            onSearch: (value) => setState(() {
              query = value;
              if (value.trim().isNotEmpty) _collapsedMapFleetKeys.clear();
            }),
            onStatusChanged: (value) => setState(() => statusFilter = value),
            onAutoRefreshChanged: (value) {
              setState(() => autoRefresh = value);
              if (value) {
                _startLiveRefresh();
              } else {
                refreshTimer?.cancel();
              }
            },
            onSelect: (vehicle) => _selectVehicle(vehicle, compact: compact),
            onClose: () => setState(() => panelVisible = false),
          ),
        ),
        if (!compact)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            left: panelVisible ? panelWidth + 24 : 16,
            top: 16,
            child: _MapIconButton(
              tooltip: panelVisible
                  ? context.tr('hide_map_menu')
                  : context.tr('show_map_menu'),
              icon: panelVisible ? Icons.chevron_left : Icons.menu,
              onPressed: () {
                final showPanel = !panelVisible;
                if (compact && showPanel) selectedTelemetryTimer?.cancel();
                setState(() {
                  panelVisible = showPanel;
                  if (compact && showPanel) {
                    selectedVehicle = null;
                    _clearHistory();
                  }
                });
              },
            ),
          ),
        if (compact && !panelVisible)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: _MapMobileTopBar(
              refreshing: refreshing,
              selectedVehicle: selectedVehicle,
              onMenu: () {
                selectedTelemetryTimer?.cancel();
                setState(() {
                  selectedVehicle = null;
                  _clearHistory();
                  panelVisible = true;
                });
              },
              onRefresh: refreshing
                  ? null
                  : () => _refreshLive(showError: true),
              onDetails: selectedVehicle == null
                  ? null
                  : () => showVehicleDetailsSheet(
                      context,
                      widget.session,
                      selectedVehicle!,
                    ),
              onTrips: selectedVehicle == null
                  ? null
                  : () => _openTripHistory(selectedVehicle!),
              onEvents: selectedVehicle == null
                  ? null
                  : () => showVehicleEventsSheet(
                      context,
                      widget.session,
                      selectedVehicle!,
                    ),
            ),
          ),
        if (!compact || !panelVisible)
          Positioned(
            right: 16,
            top: historyVehicle != null && !historyWide
                ? null
                : compact
                ? (selectedVehicle == null ? 72 : 142)
                : 16,
            bottom: historyVehicle != null && !historyWide ? 16 : null,
            child: Column(
              children: [
                _MapIconButton(
                  tooltip: context.tr('my_location'),
                  icon: Icons.my_location,
                  onPressed: _centerOnUser,
                ),
                const SizedBox(height: 10),
                _MapIconButton(
                  tooltip: context.tr('view_all'),
                  icon: Icons.center_focus_strong,
                  onPressed: () => _fitVehicles(vehicles),
                ),
              ],
            ),
          ),
        if (compact && selectedVehicle != null && !panelVisible)
          Positioned(
            left: 0,
            right: 0,
            top: 58,
            child: SelectedVehicleTopStrip(
              vehicle: selectedVehicle!,
              details: selectedVehicleDetails?.vehicle.id == selectedVehicle!.id
                  ? selectedVehicleDetails
                  : null,
            ),
          ),
        if (selectedVehicle != null &&
            !compact &&
            !panelVisible &&
            historyVehicle == null)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            left: selectedPanelLeft,
            right: 16,
            bottom: 16,
            child: _SelectedVehiclePanel(
              vehicle: selectedVehicle!,
              onClose: () {
                selectedTelemetryTimer?.cancel();
                setState(() {
                  selectedVehicle = null;
                  _clearHistory();
                });
              },
              onDetails: () => showVehicleDetailsSheet(
                context,
                widget.session,
                selectedVehicle!,
              ),
              onTrips: () => _openTripHistory(selectedVehicle!),
              onEvents: () => showVehicleEventsSheet(
                context,
                widget.session,
                selectedVehicle!,
              ),
            ),
          ),
        if (historyVehicle != null)
          Positioned(
            left: 12,
            top: historyTop,
            width: historyWidth,
            child: ConstrainedBox(
              key: historyPanelKey,
              constraints: BoxConstraints(maxHeight: historyHeight),
              child: TripHistoryPanel(
                key: ValueKey(historyVehicle!.id),
                vehicleName: historyVehicle!.name,
                active: widget.active,
                onCollapsedChanged: (value) =>
                    setState(() => historyCollapsed = value),
                load: (period, from, to) => widget.session.vehicleTrips(
                  historyVehicle!.id,
                  period: period,
                  startDate: from,
                  endDate: to,
                ),
                onSelection: _showHistorySelection,
                onPlayback: _showHistoryPlayback,
                onClose: () => setState(_clearHistory),
              ),
            ),
          ),
      ],
    );
  }

  Set<Marker> _markers(List<VehicleData> vehicles) {
    if (historyVehicle != null) return {...historyPins.values, ?historyReplay};
    return vehicles.map((vehicle) {
      final position =
          displayedPositions[vehicle.id] ??
          LatLng(vehicle.latitude!, vehicle.longitude!);
      return Marker(
        markerId: MarkerId('vehicle-${vehicle.id}'),
        position: position,
        icon: _markerIcon(vehicle),
        anchor: const Offset(0.5, 0.5),
        flat: vehicle.isMoving,
        rotation: vehicle.isMoving ? (vehicle.heading ?? 0).toDouble() : 0,
        infoWindow: InfoWindow(
          title: vehicle.name,
          snippet: '${vehicle.registration} · ${vehicle.speed} km/h',
        ),
        onTap: () => _selectVehicle(vehicle),
      );
    }).toSet();
  }

  Set<Polyline> _polylines() {
    final polylines = <Polyline>{};
    if (historyVehicle != null) {
      return historyTrips
          .where((t) => t.coordinates.length > 1)
          .map(
            (t) => Polyline(
              polylineId: PolylineId(t.id),
              points: t.coordinates
                  .map((p) => LatLng(p.latitude, p.longitude))
                  .toList(),
              color: t.color,
              width: 5,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
          )
          .toSet();
    }
    for (final vehicle in positionedVehicles.where(
      (vehicle) => vehicle.isMoving && vehicle.trail.length > 1,
    )) {
      final points = _visibleTrailPoints(vehicle);
      if (points.length < 2) continue;
      polylines.add(
        Polyline(
          polylineId: PolylineId('live-${vehicle.id}'),
          points: points,
          color: const Color(0xFF229BD8).withValues(alpha: .55),
          width: 4,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    return polylines;
  }

  List<LatLng> _visibleTrailPoints(VehicleData vehicle) {
    final trail = vehicle.trail
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    final current = displayedPositions[vehicle.id];
    if (trail.length < 2 || current == null) return trail;

    var closestIndex = 0;
    var closestDistance = double.infinity;
    for (var index = 0; index < trail.length; index++) {
      final distance = _distanceBetween(current, trail[index]);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = index;
      }
    }
    final visible = trail.take(closestIndex + 1).toList();
    if (visible.isEmpty || !_samePosition(visible.last, current)) {
      visible.add(current);
    }
    return visible;
  }

  BitmapDescriptor _markerIcon(VehicleData vehicle) {
    final state = _markerState(vehicle);
    return markerIcons[state] ??
        BitmapDescriptor.defaultMarkerWithHue(_fallbackMarkerHue(state));
  }

  _VehicleMarkerState _markerState(VehicleData vehicle) {
    if (vehicle.isMoving) return _VehicleMarkerState.moving;
    if (vehicle.isParking) return _VehicleMarkerState.parking;
    if (vehicle.isStationaryRunning) {
      return _VehicleMarkerState.stationaryRunning;
    }
    if (vehicle.trackingStatus == 'maintenance') {
      return _VehicleMarkerState.maintenance;
    }
    if (vehicle.trackingStatus == 'inactive') {
      return _VehicleMarkerState.inactive;
    }
    if (!vehicle.isOnline) return _VehicleMarkerState.offline;
    return _VehicleMarkerState.online;
  }

  Color _markerColor(_VehicleMarkerState state) {
    return switch (state) {
      _VehicleMarkerState.moving => const Color(0xFF10B981),
      _VehicleMarkerState.parking => const Color(0xFF22A7DF),
      _VehicleMarkerState.stationaryRunning => const Color(0xFF229BD8),
      _VehicleMarkerState.maintenance => const Color(0xFF8B5CF6),
      _VehicleMarkerState.inactive => const Color(0xFFEF4444),
      _VehicleMarkerState.offline => const Color(0xFFEF4444),
      _VehicleMarkerState.online => const Color(0xFF10B981),
    };
  }

  double _fallbackMarkerHue(_VehicleMarkerState state) {
    return switch (state) {
      _VehicleMarkerState.moving => BitmapDescriptor.hueGreen,
      _VehicleMarkerState.parking => BitmapDescriptor.hueCyan,
      _VehicleMarkerState.stationaryRunning => BitmapDescriptor.hueBlue,
      _VehicleMarkerState.maintenance => BitmapDescriptor.hueViolet,
      _VehicleMarkerState.inactive => BitmapDescriptor.hueRed,
      _VehicleMarkerState.offline => BitmapDescriptor.hueRed,
      _VehicleMarkerState.online => BitmapDescriptor.hueGreen,
    };
  }

  void _selectVehicle(VehicleData vehicle, {bool compact = false}) {
    vehicle =
        liveVehicles.where((item) => item.id == vehicle.id).firstOrNull ??
        vehicle;
    if (vehicle.latitude == null || vehicle.longitude == null) return;
    final latestPosition = LatLng(vehicle.latitude!, vehicle.longitude!);
    motions.remove(vehicle.id);
    displayedPositions[vehicle.id] = latestPosition;
    _snapOnNextUpdate.add(vehicle.id);
    lastCameraFollowAt = null;
    setState(() {
      selectedVehicle = vehicle;
      if (selectedVehicleDetails?.vehicle.id != vehicle.id) {
        selectedVehicleDetails = null;
      }
      _clearHistory();
      if (compact || MediaQuery.sizeOf(context).width < 720) {
        panelVisible = false;
      }
    });
    unawaited(
      mapController?.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latestPosition, zoom: selectedVehicleZoom),
        ),
      ),
    );
    _startSelectedTelemetryRefresh();
    unawaited(_refreshLive());
  }

  Future<void> _loadSelectedVehicleTelemetry(int vehicleId) async {
    try {
      final details = await widget.session.vehicleDetails(vehicleId);
      if (!mounted || selectedVehicle?.id != vehicleId) return;
      setState(() => selectedVehicleDetails = details);
    } catch (_) {
      // The live map remains usable when optional telemetry is unavailable.
    }
  }

  void _handleFocusRequest() {
    final requested = widget.focusVehicle;
    if (!mounted ||
        !widget.active ||
        widget.focusRequestId <= handledFocusRequestId) {
      return;
    }

    if (requested == null) {
      if (mapController == null) return;
      selectedTelemetryTimer?.cancel();
      setState(() {
        selectedVehicle = null;
        _clearHistory();
        panelVisible = true;
      });
      handledFocusRequestId = widget.focusRequestId;
      unawaited(_fitVehicles(positionedVehicles));
      return;
    }

    final vehicle = liveVehicles
        .where((item) => item.id == requested.id)
        .firstOrNull;
    final focusVehicle = vehicle ?? requested;
    if (focusVehicle.latitude == null || focusVehicle.longitude == null) {
      return;
    }

    _selectVehicle(
      focusVehicle,
      compact: MediaQuery.sizeOf(context).width < 720,
    );
    if (mapController != null) {
      handledFocusRequestId = widget.focusRequestId;
    }
  }

  void _clearHistory() {
    historyGeneration++;
    historyVehicle = null;
    historyCollapsed = false;
    historyPanelHeight = null;
    historyLayoutGeneration++;
    historyPoints = [];
    historyTrips = [];
    historyPins.clear();
    historyReplay = null;
  }

  void _openTripHistory(VehicleData vehicle) {
    setState(() {
      _clearHistory();
      historyVehicle = vehicle;
      panelVisible = false;
    });
  }

  void _showHistorySelection(
    List<VehicleTripData> trips,
    VehicleHistoryItem? parking,
  ) {
    final generation = ++historyGeneration;
    setState(() {
      historyTrips = trips;
      historyPins.clear();
      historyReplay = null;
    });
    final points = trips
        .expand((t) => t.coordinates)
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    if (parking?.coordinate != null) {
      final p = parking!.coordinate!;
      final point = LatLng(p.latitude, p.longitude);
      points.add(point);
      unawaited(
        _historyPin(
          'parking',
          point,
          Colors.grey,
          'P',
          parking.address,
          generation,
        ),
      );
    } else if (trips.isNotEmpty) {
      final first = trips.first, last = trips.last;
      final start = first.startCoordinate ?? first.coordinates.firstOrNull;
      final end = last.endCoordinate ?? last.coordinates.lastOrNull;
      if (start != null) {
        unawaited(
          _historyPin(
            'start',
            LatLng(start.latitude, start.longitude),
            first.color,
            'start',
            first.startAddress,
            generation,
          ),
        );
      }
      if (end != null) {
        unawaited(
          _historyPin(
            'finish',
            LatLng(end.latitude, end.longitude),
            last.color,
            'finish',
            last.endAddress,
            generation,
          ),
        );
      }
    }
    historyPoints = points;
    _scheduleHistoryFit();
  }

  void _scheduleHistoryFit() {
    final generation = ++historyLayoutGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Let the measured panel padding reach the native map before fitting.
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (mounted &&
          historyVehicle != null &&
          generation == historyLayoutGeneration) {
        unawaited(_fitPoints(historyPoints));
      }
    });
  }

  Future<void> _historyPin(
    String id,
    LatLng point,
    Color color,
    String kind,
    String address,
    int generation,
  ) async {
    final recorder = ui.PictureRecorder(),
        paint = Paint()..color = Colors.white;
    final canvas = Canvas(recorder);
    final shape = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(5, 5, 70, 65),
          const Radius.circular(10),
        ),
      )
      ..moveTo(28, 69)
      ..lineTo(40, 87)
      ..lineTo(52, 69)
      ..close();
    canvas.drawShadow(shape, Colors.black, 3, true);
    canvas.drawPath(shape, paint);
    canvas.drawPath(
      shape,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    if (kind == 'finish') {
      for (var x = 0; x < 4; x++) {
        for (var y = 0; y < 4; y++) {
          if ((x + y).isEven) {
            canvas.drawRect(
              Rect.fromLTWH(23 + x * 9, 18 + y * 9, 9, 9),
              Paint()..color = color,
            );
          }
        }
      }
      canvas.drawLine(
        const Offset(21, 17),
        const Offset(21, 59),
        Paint()
          ..color = color
          ..strokeWidth = 3,
      );
    } else if (kind == 'start') {
      canvas.drawCircle(
        const Offset(40, 36),
        21,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawPath(
        Path()
          ..moveTo(34, 23)
          ..lineTo(53, 36)
          ..lineTo(34, 49)
          ..close(),
        Paint()..color = color,
      );
    } else {
      final text = TextPainter(
        text: TextSpan(
          text: kind,
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset((80 - text.width) / 2, 12));
    }
    final picture = recorder.endRecording(),
        image = await picture.toImage(80, 90);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (!mounted || generation != historyGeneration || bytes == null) return;
    final title = kind == 'start'
        ? context.tr('history_start')
        : kind == 'finish'
        ? context.tr('history_finish')
        : context.tr('history_parking');
    setState(
      () => historyPins[id] = Marker(
        markerId: MarkerId('history-$id'),
        position: point,
        anchor: const Offset(.5, .98),
        icon: BitmapDescriptor.bytes(
          bytes.buffer.asUint8List(),
          width: 40,
          height: 45,
        ),
        infoWindow: InfoWindow(title: title, snippet: address),
      ),
    );
  }

  void _showHistoryPlayback(VehicleTripData trip, double progress) {
    final path = trip.coordinates
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    if (path.isEmpty || historyVehicle == null) return;
    setState(
      () => historyReplay = Marker(
        markerId: const MarkerId('history-replay'),
        position: _positionAlongPath(path, progress),
        icon:
            markerIcons[_VehicleMarkerState.moving] ??
            BitmapDescriptor.defaultMarker,
        anchor: const Offset(.5, .5),
        zIndexInt: 100,
      ),
    );
  }

  Future<void> _fitVehicles(List<VehicleData> vehicles) async {
    await _fitPoints(
      vehicles
          .map(
            (vehicle) =>
                displayedPositions[vehicle.id] ??
                LatLng(vehicle.latitude!, vehicle.longitude!),
          )
          .toList(),
    );
  }

  Future<void> _fitPoints(List<LatLng> points) async {
    final controller = mapController;
    if (controller == null || points.isEmpty) return;
    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          points.first,
          historyVehicle == null ? selectedVehicleZoom : 15,
        ),
      );
      return;
    }

    var south = points.first.latitude;
    var north = points.first.latitude;
    var west = points.first.longitude;
    var east = points.first.longitude;
    for (final point in points.skip(1)) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        historyVehicle == null ? 24 : 48,
      ),
    );
  }

  Future<void> _centerOnUser() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!serviceEnabled) {
      await _showLocationDialog(
        message: context.tr('location_service_disabled'),
        onOpenSettings: Geolocator.openLocationSettings,
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final accepted = await _showLocationRationale();
      if (!accepted) return;
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) return;
    if (permission == LocationPermission.deniedForever) {
      await _showLocationDialog(
        message: context.tr('location_permission_denied'),
        onOpenSettings: Geolocator.openAppSettings,
      );
      return;
    }
    if (permission == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('location_permission_denied'))),
      );
      return;
    }

    try {
      setState(() => myLocationEnabled = true);
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      await mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          initialStreetZoom,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('location_unavailable'))),
      );
    }
  }

  Future<bool> _showLocationRationale() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.location_on_outlined),
            title: Text(context.tr('location_permission_title')),
            content: Text(context.tr('location_permission_help')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.tr('not_now')),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.my_location),
                label: Text(context.tr('allow')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showLocationDialog({
    required String message,
    required Future<bool> Function() onOpenSettings,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.location_on_outlined),
        title: Text(context.tr('location_permission_title')),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('not_now')),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(onOpenSettings());
            },
            icon: const Icon(Icons.settings_outlined),
            label: Text(context.tr('open_settings')),
          ),
        ],
      ),
    );
  }
}

enum _VehicleMarkerState {
  moving,
  parking,
  stationaryRunning,
  maintenance,
  inactive,
  offline,
  online,
}

class _VehicleMotion {
  const _VehicleMotion({
    required this.path,
    required this.startedAt,
    required this.duration,
  });

  final List<LatLng> path;
  final DateTime startedAt;
  final Duration duration;
}

class _VehicleMapPanel extends StatelessWidget {
  const _VehicleMapPanel({
    required this.compact,
    required this.allVehicles,
    required this.searchController,
    required this.vehicles,
    required this.collapsedFleetKeys,
    required this.onToggleFleet,
    required this.selectedVehicle,
    required this.statusFilter,
    required this.autoRefresh,
    required this.refreshing,
    required this.lastUpdatedAt,
    required this.onRefresh,
    required this.onSearch,
    required this.onStatusChanged,
    required this.onAutoRefreshChanged,
    required this.onSelect,
    required this.onClose,
  });

  final bool compact;
  final List<VehicleData> allVehicles;
  final TextEditingController searchController;
  final List<VehicleData> vehicles;
  final Set<String> collapsedFleetKeys;
  final ValueChanged<String> onToggleFleet;
  final VehicleData? selectedVehicle;
  final String statusFilter;
  final bool autoRefresh;
  final bool refreshing;
  final DateTime? lastUpdatedAt;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<bool> onAutoRefreshChanged;
  final ValueChanged<VehicleData> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groupedVehicles = <String, List<VehicleData>>{};
    for (final vehicle in vehicles) {
      final fleetKey = vehicle.fleet == null
          ? 'unassigned'
          : 'fleet-${vehicle.fleet!.id}';
      groupedVehicles.putIfAbsent(fleetKey, () => []).add(vehicle);
    }

    return Material(
      color: scheme.surface,
      elevation: compact ? 12 : 3,
      shadowColor: const Color(0x440F172A),
      borderRadius: compact ? BorderRadius.zero : BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 58,
            color: scheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: context.tr('hide_map_menu'),
                  onPressed: onClose,
                  color: Colors.white,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Text(
                    context.tr('vehicles'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: context.tr('filter'),
                  initialValue: statusFilter,
                  color: scheme.surface,
                  iconColor: Colors.white,
                  icon: const Icon(Icons.filter_alt_outlined),
                  onSelected: onStatusChanged,
                  itemBuilder: (context) => [
                    _statusMenuItem(context, 'all', context.tr('all')),
                    _statusMenuItem(context, 'online', context.tr('online')),
                    _statusMenuItem(
                      context,
                      'moving',
                      context.tr('moving_now'),
                    ),
                    _statusMenuItem(context, 'parking', context.tr('parking')),
                    _statusMenuItem(context, 'offline', context.tr('offline')),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 11),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _VehicleStatusTotal(
                    icon: FleetStatusSymbol.online,
                    color: const Color(0xFF10B981),
                    count: allVehicles
                        .where((vehicle) => vehicle.isOnline)
                        .length,
                    label: context.tr('online'),
                  ),
                ),
                _StatusDivider(color: Theme.of(context).dividerColor),
                Expanded(
                  child: _VehicleStatusTotal(
                    icon: FleetStatusSymbol.offline,
                    color: const Color(0xFFEF4444),
                    count: allVehicles
                        .where((vehicle) => !vehicle.isOnline)
                        .length,
                    label: context.tr('offline'),
                  ),
                ),
                _StatusDivider(color: Theme.of(context).dividerColor),
                Expanded(
                  child: _VehicleStatusTotal(
                    icon: FleetStatusSymbol.moving,
                    color: const Color(0xFF10B981),
                    count: allVehicles
                        .where((vehicle) => vehicle.isMoving)
                        .length,
                    label: context.tr('moving_now'),
                  ),
                ),
                _StatusDivider(color: Theme.of(context).dividerColor),
                Expanded(
                  child: _VehicleStatusTotal(
                    icon: FleetStatusSymbol.parked,
                    color: const Color(0xFF22A7DF),
                    count: allVehicles
                        .where((vehicle) => vehicle.isParking)
                        .length,
                    label: context.tr('parking_total'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  onChanged: onSearch,
                  decoration: InputDecoration(
                    hintText: context.tr('search_vehicle'),
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(
                      tooltip: context.tr('refresh'),
                      onPressed: refreshing ? null : onRefresh,
                      visualDensity: VisualDensity.compact,
                      icon: refreshing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 19),
                      color: scheme.secondary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _updatedLabel(context),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Switch.adaptive(
                      value: autoRefresh,
                      onChanged: onAutoRefreshChanged,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: vehicles.isEmpty
                ? EmptyState(
                    icon: Icons.search_off,
                    message: context.tr('no_search_result'),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: groupedVehicles.entries.expand((entry) {
                      final fleetName = entry.value.first.fleet?.name.trim();
                      final name = fleetName?.isNotEmpty == true
                          ? fleetName!
                          : context.tr('vehicles');
                      final collapsed = collapsedFleetKeys.contains(entry.key);
                      return <Widget>[
                        _VehicleGroupHeader(
                          name: name,
                          count: entry.value.length,
                          collapsed: collapsed,
                          onToggle: () => onToggleFleet(entry.key),
                        ),
                        if (!collapsed)
                          ...entry.value.map(
                            (vehicle) => _MapDrawerVehicleRow(
                              vehicle: vehicle,
                              selected: vehicle.id == selectedVehicle?.id,
                              onTap: () => onSelect(vehicle),
                            ),
                          ),
                      ];
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _statusMenuItem(
    BuildContext context,
    String value,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: statusFilter == value
                ? Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.secondary,
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  String _updatedLabel(BuildContext context) {
    if (refreshing) return context.tr('updating');
    final updated = lastUpdatedAt;
    if (updated == null) return context.tr('waiting_for_update');
    final hour = updated.hour.toString().padLeft(2, '0');
    final minute = updated.minute.toString().padLeft(2, '0');
    final second = updated.second.toString().padLeft(2, '0');
    return context.trFormat('updated_at', {'time': '$hour:$minute:$second'});
  }
}

class _VehicleStatusTotal extends StatelessWidget {
  const _VehicleStatusTotal({
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
  });

  final FleetStatusSymbol icon;
  final Color color;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label : $count',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FleetStatusIcon(symbol: icon, color: color),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 16,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDivider extends StatelessWidget {
  const _StatusDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      color: color.withValues(alpha: .65),
    );
  }
}

class _VehicleGroupHeader extends StatelessWidget {
  const _VehicleGroupHeader({
    required this.name,
    required this.count,
    required this.collapsed,
    required this.onToggle,
  });

  final String name;
  final int count;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      expanded: !collapsed,
      label: context.trFormat(collapsed ? 'expand_fleet' : 'collapse_fleet', {
        'name': name,
      }),
      child: Material(
        color: scheme.primary.withValues(alpha: .045),
        child: InkWell(
          onTap: onToggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.corporate_fare_outlined,
                    size: 17,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: collapsed ? -.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 21,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapDrawerVehicleRow extends StatelessWidget {
  const _MapDrawerVehicleRow({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final VehicleData vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = vehicleMarkerColor(vehicle);

    return Material(
      color: selected
          ? scheme.secondary.withValues(alpha: .12)
          : scheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 57),
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
              left: BorderSide(
                color: selected ? scheme.secondary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  vehicleMarkerIcon(vehicle),
                  size: 19,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      vehicle.registration,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 9.5,
                      ),
                    ),
                    if (vehicle.fuel != null) ...[
                      const SizedBox(height: 5),
                      FuelLevelBadge(fuel: vehicle.fuel!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${vehicle.speed} km/h',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedVehiclePanel extends StatelessWidget {
  const _SelectedVehiclePanel({
    required this.vehicle,
    required this.onClose,
    required this.onDetails,
    required this.onTrips,
    required this.onEvents,
  });

  final VehicleData vehicle;
  final VoidCallback onClose;
  final VoidCallback onDetails;
  final VoidCallback onTrips;
  final VoidCallback onEvents;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 4,
      shadowColor: const Color(0x330F172A),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: VehicleRow(vehicle: vehicle)),
                IconButton(
                  tooltip: context.tr('close'),
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 16),
            SizedBox(
              height: 46,
              child: Row(
                children: [
                  Expanded(
                    child: _VehicleActionButton(
                      onPressed: onDetails,
                      icon: Icons.info_outline,
                      label: context.tr('details'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _VehicleActionButton(
                      onPressed: onTrips,
                      icon: Icons.alt_route,
                      label: context.tr('trips'),
                      emphasized: true,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _VehicleActionButton(
                      onPressed: onEvents,
                      icon: Icons.notifications_outlined,
                      label: context.tr('events'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleActionButton extends StatelessWidget {
  const _VehicleActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 7),
      ),
      visualDensity: VisualDensity.compact,
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      foregroundColor: WidgetStatePropertyAll(
        dark ? scheme.onSurface : scheme.primary,
      ),
      side: WidgetStatePropertyAll(
        BorderSide(
          color: dark
              ? scheme.onSurfaceVariant.withValues(alpha: .75)
              : Theme.of(context).dividerColor,
        ),
      ),
    );
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 5),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );

    if (emphasized) {
      return FilledButton.tonal(
        onPressed: onPressed,
        style: style.copyWith(
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          backgroundColor: WidgetStatePropertyAll(
            dark ? const Color(0xFF312E81) : scheme.primary,
          ),
          side: const WidgetStatePropertyAll(BorderSide.none),
        ),
        child: content,
      );
    }

    return OutlinedButton(onPressed: onPressed, style: style, child: content);
  }
}

class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _MapMobileTopBar extends StatelessWidget {
  const _MapMobileTopBar({
    required this.refreshing,
    required this.selectedVehicle,
    required this.onMenu,
    required this.onRefresh,
    required this.onDetails,
    required this.onTrips,
    required this.onEvents,
  });

  final bool refreshing;
  final VehicleData? selectedVehicle;
  final VoidCallback onMenu;
  final VoidCallback? onRefresh;
  final VoidCallback? onDetails;
  final VoidCallback? onTrips;
  final VoidCallback? onEvents;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      elevation: 4,
      shadowColor: const Color(0x330F172A),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            IconButton(
              tooltip: context.tr('show_map_menu'),
              onPressed: onMenu,
              color: Colors.white,
              icon: const Icon(Icons.menu_rounded, size: 24),
            ),
            Expanded(
              child: Text(
                context.tr('map'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.2,
                ),
              ),
            ),
            if (selectedVehicle == null)
              IconButton(
                tooltip: context.tr('refresh'),
                onPressed: onRefresh,
                color: Colors.white,
                icon: refreshing
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
              )
            else ...[
              _MapHeaderAction(
                tooltip: context.tr('details'),
                icon: Icons.info_outline_rounded,
                onPressed: onDetails,
              ),
              _MapHeaderAction(
                tooltip: context.tr('trips'),
                icon: Icons.alt_route_rounded,
                onPressed: onTrips,
              ),
              _MapHeaderAction(
                tooltip: context.tr('events'),
                icon: Icons.notifications_none_rounded,
                onPressed: onEvents,
              ),
            ],
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _MapHeaderAction extends StatelessWidget {
  const _MapHeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 44),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(icon, size: 20, color: Colors.white),
    );
  }
}
