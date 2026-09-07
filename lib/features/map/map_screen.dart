import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui_components.dart';
import 'map_vehicle_sheets.dart';

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
  static const initialStreetZoom = 15.5;

  final searchController = TextEditingController();
  GoogleMapController? mapController;
  VehicleData? selectedVehicle;
  VehicleDetailData? selectedVehicleDetails;
  VehicleTripData? selectedTrip;
  List<VehicleData> liveVehicles = const [];
  final Map<int, LatLng> displayedPositions = {};
  final Map<int, _VehicleMotion> motions = {};
  final Map<_VehicleMarkerState, BitmapDescriptor> markerIcons = {};
  Timer? refreshTimer;
  Timer? selectedTelemetryTimer;
  Timer? animationTimer;
  String query = '';
  String statusFilter = 'all';
  bool panelVisible = false;
  bool myLocationEnabled = false;
  bool autoRefresh = true;
  bool refreshing = false;
  DateTime? lastUpdatedAt;
  DateTime? lastCameraFollowAt;
  int handledFocusRequestId = 0;

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
    if (state == AppLifecycleState.resumed && widget.active) {
      _startLiveRefresh();
      _startSelectedTelemetryRefresh();
      return;
    }
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

  void _startLiveRefresh() {
    refreshTimer?.cancel();
    if (!widget.active || !autoRefresh) return;
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
    if (refreshing || !mounted) return;
    setState(() => refreshing = true);
    try {
      final snapshot = await widget.session.mapSnapshot();
      if (!mounted) return;
      _applySnapshot(snapshot);
      if (fit) await _fitVehicles(positionedVehicles);
    } catch (_) {
      if (!mounted || !showError) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('map_refresh_failed'))));
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  void _applySnapshot(List<VehicleData> snapshot) {
    final nextIds = snapshot.map((vehicle) => vehicle.id).toSet();
    displayedPositions.removeWhere((id, _) => !nextIds.contains(id));
    motions.removeWhere((id, _) => !nextIds.contains(id));

    for (final vehicle in snapshot) {
      if (vehicle.latitude == null || vehicle.longitude == null) continue;
      final target = LatLng(vehicle.latitude!, vehicle.longitude!);
      final current = displayedPositions[vehicle.id] ?? target;
      if (vehicle.isMoving && !_samePosition(current, target)) {
        motions[vehicle.id] = _VehicleMotion(
          path: _motionPath(vehicle, current, target),
          startedAt: DateTime.now(),
          duration: markerAnimationDuration,
        );
      } else {
        displayedPositions[vehicle.id] = target;
        motions.remove(vehicle.id);
      }
    }

    final selectedId = selectedVehicle?.id;
    setState(() {
      liveVehicles = List<VehicleData>.of(snapshot);
      selectedVehicle = selectedId == null
          ? null
          : snapshot.where((vehicle) => vehicle.id == selectedId).firstOrNull;
      lastUpdatedAt = DateTime.now();
    });
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
    if (motions.isEmpty || animationTimer?.isActive == true) return;
    animationTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || motions.isEmpty) {
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
    final compact = constraints.maxWidth < 720;
    final panelWidth = compact
        ? (constraints.maxWidth * .82).clamp(280.0, 360.0).toDouble()
        : 340.0;
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
            userName: widget.session.user?.name ?? '',
            userEmail: widget.session.user?.email ?? '',
            searchController: searchController,
            vehicles: filteredVehicles,
            selectedVehicle: selectedVehicle,
            statusFilter: statusFilter,
            autoRefresh: autoRefresh,
            refreshing: refreshing,
            lastUpdatedAt: lastUpdatedAt,
            onRefresh: () => _refreshLive(showError: true),
            onSearch: (value) => setState(() => query = value),
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
                    selectedTrip = null;
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
                  selectedTrip = null;
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
                  : () => showVehicleTripsSheet(
                      context,
                      widget.session,
                      selectedVehicle!,
                      _showTrip,
                    ),
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
            top: compact ? (selectedVehicle == null ? 72 : 142) : 16,
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
            child: _SelectedVehicleTopStrip(
              vehicle: selectedVehicle!,
              details: selectedVehicleDetails?.vehicle.id == selectedVehicle!.id
                  ? selectedVehicleDetails
                  : null,
            ),
          ),
        if (selectedVehicle != null && !compact && !panelVisible)
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
                  selectedTrip = null;
                });
              },
              onDetails: () => showVehicleDetailsSheet(
                context,
                widget.session,
                selectedVehicle!,
              ),
              onTrips: () => showVehicleTripsSheet(
                context,
                widget.session,
                selectedVehicle!,
                _showTrip,
              ),
              onEvents: () => showVehicleEventsSheet(
                context,
                widget.session,
                selectedVehicle!,
              ),
            ),
          ),
      ],
    );
  }

  Set<Marker> _markers(List<VehicleData> vehicles) {
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

    final trip = selectedTrip;
    if (trip != null && trip.coordinates.length > 1) {
      polylines.add(
        Polyline(
          polylineId: PolylineId(trip.id),
          points: trip.coordinates
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList(),
          color: trip.color,
          width: 5,
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
      _VehicleMarkerState.moving => const Color(0xFF229BD8),
      _VehicleMarkerState.parking => const Color(0xFF22A7DF),
      _VehicleMarkerState.stationaryRunning => const Color(0xFF229BD8),
      _VehicleMarkerState.maintenance => const Color(0xFF8B5CF6),
      _VehicleMarkerState.inactive => const Color(0xFFEF4444),
      _VehicleMarkerState.offline => const Color(0xFFF59E0B),
      _VehicleMarkerState.online => const Color(0xFF10B981),
    };
  }

  double _fallbackMarkerHue(_VehicleMarkerState state) {
    return switch (state) {
      _VehicleMarkerState.moving => BitmapDescriptor.hueAzure,
      _VehicleMarkerState.parking => BitmapDescriptor.hueCyan,
      _VehicleMarkerState.stationaryRunning => BitmapDescriptor.hueBlue,
      _VehicleMarkerState.maintenance => BitmapDescriptor.hueViolet,
      _VehicleMarkerState.inactive => BitmapDescriptor.hueRed,
      _VehicleMarkerState.offline => BitmapDescriptor.hueOrange,
      _VehicleMarkerState.online => BitmapDescriptor.hueGreen,
    };
  }

  void _selectVehicle(VehicleData vehicle, {bool compact = false}) {
    setState(() {
      selectedVehicle = vehicle;
      if (selectedVehicleDetails?.vehicle.id != vehicle.id) {
        selectedVehicleDetails = null;
      }
      selectedTrip = null;
      if (compact || MediaQuery.sizeOf(context).width < 720) {
        panelVisible = false;
      }
    });
    unawaited(
      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target:
                displayedPositions[vehicle.id] ??
                LatLng(vehicle.latitude!, vehicle.longitude!),
            zoom: 17,
          ),
        ),
      ),
    );
    _startSelectedTelemetryRefresh();
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
        selectedTrip = null;
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

  void _showTrip(VehicleTripData trip) {
    if (trip.coordinates.isEmpty) return;
    setState(() => selectedTrip = trip);
    final points = trip.coordinates
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    unawaited(_fitPoints(points));
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
        CameraUpdate.newLatLngZoom(points.first, 15),
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
        72,
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
          16,
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
    required this.userName,
    required this.userEmail,
    required this.searchController,
    required this.vehicles,
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
  final String userName;
  final String userEmail;
  final TextEditingController searchController;
  final List<VehicleData> vehicles;
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
      final fleetName = vehicle.fleet?.name.trim();
      final groupName = fleetName?.isNotEmpty == true
          ? fleetName!
          : context.tr('vehicles');
      groupedVehicles.putIfAbsent(groupName, () => []).add(vehicle);
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
                CircleAvatar(
                  radius: 23,
                  backgroundColor: scheme.secondary.withValues(alpha: .14),
                  foregroundColor: scheme.primary,
                  child: Text(
                    _initials(userName),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.tr('refresh'),
                  visualDensity: VisualDensity.compact,
                  onPressed: refreshing ? null : onRefresh,
                  icon: refreshing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
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
                    Icon(
                      refreshing ? Icons.sync : Icons.schedule,
                      size: 17,
                      color: Theme.of(context).colorScheme.secondary,
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
                      return <Widget>[
                        _VehicleGroupHeader(
                          name: entry.key,
                          count: entry.value.length,
                        ),
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

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'EX';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
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

class _VehicleGroupHeader extends StatelessWidget {
  const _VehicleGroupHeader({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: scheme.primary.withValues(alpha: .07),
      alignment: Alignment.centerLeft,
      child: Text(
        '$name ($count)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w800,
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
    final statusColor = vehicle.isMoving
        ? const Color(0xFF229BD8)
        : vehicle.isOnline
        ? const Color(0xFF22C55E)
        : const Color(0xFFF59E0B);

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
                  Icons.directions_car_filled_outlined,
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

class _SelectedVehicleTopStrip extends StatelessWidget {
  const _SelectedVehicleTopStrip({required this.vehicle, this.details});

  final VehicleData vehicle;
  final VehicleDetailData? details;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gpsQualityPercent =
        vehicle.gpsQualityPercent ?? details?.location?.gpsQualityPercent;
    final networkSignalPercent =
        vehicle.networkSignalPercent ?? details?.gsm?.signalPercent;
    final batteryLevelPercent =
        vehicle.batteryLevelPercent ??
        details?.power?.effectiveBatteryLevelPercent;
    final gpsAvailable =
        vehicle.hasAvailableGps ||
        (vehicle.isOnline && (gpsQualityPercent ?? 0) > 0);
    final isParking = vehicle.isParking || details?.location?.ignition == false;
    final gpsColor = gpsAvailable ? AppTheme.success : AppTheme.danger;
    final networkColor = _levelColor(networkSignalPercent);
    final batteryColor = _levelColor(batteryLevelPercent);

    return Material(
      color: scheme.surface,
      elevation: 3,
      shadowColor: const Color(0x260F172A),
      child: SizedBox(
        height: 70,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.navigation_rounded,
                    size: 18,
                    color: vehicle.isMoving
                        ? scheme.secondary
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      vehicle.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _lastSignalLabel(context),
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _TrackingMetric(
                      icon: gpsAvailable
                          ? Icons.gps_fixed_rounded
                          : Icons.gps_off_rounded,
                      value: context.tr(
                        gpsAvailable ? 'gps_active' : 'gps_unavailable',
                      ),
                      color: gpsColor,
                    ),
                  ),
                  Expanded(
                    child: _TrackingMetric(
                      icon: vehicle.isOnline
                          ? Icons.signal_cellular_alt_rounded
                          : Icons.signal_cellular_off_rounded,
                      value: networkSignalPercent != null
                          ? _percent(networkSignalPercent)
                          : vehicle.isOnline
                          ? context.tr('connected')
                          : context.tr('not_available_short'),
                      color: networkSignalPercent == null && vehicle.isOnline
                          ? AppTheme.success
                          : networkColor,
                    ),
                  ),
                  Expanded(
                    child: _TrackingMetric(
                      icon: Icons.battery_5_bar_rounded,
                      value: batteryLevelPercent == null
                          ? context.tr('not_available_short')
                          : _percent(batteryLevelPercent),
                      color: batteryColor,
                    ),
                  ),
                  Expanded(
                    child: _TrackingMetric(
                      icon: isParking
                          ? Icons.local_parking_rounded
                          : Icons.speed_rounded,
                      value: _movementValue(context),
                      color: scheme.onSurfaceVariant,
                      circledIcon: isParking,
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

  String _percent(int? value) {
    return value == null ? '--%' : '${value.clamp(0, 100)}%';
  }

  Color _levelColor(int? value) {
    if (value == null) return AppTheme.muted;
    if (value >= 50) return AppTheme.success;
    if (value >= 20) return AppTheme.warning;
    return AppTheme.danger;
  }

  String _movementValue(BuildContext context) {
    final isParking = vehicle.isParking || details?.location?.ignition == false;
    if (!isParking) return '${vehicle.speed} km/h';

    final startedAt = DateTime.tryParse(
      details?.location?.parkingStartedAt ?? '',
    )?.toLocal();
    if (startedAt == null) return context.tr('parking');

    final elapsed = DateTime.now().difference(startedAt);
    final minutes = elapsed.isNegative ? 0 : elapsed.inMinutes;
    if (minutes < 1) return '< 1min';
    if (minutes < 60) return '${minutes}min';

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (hours < 24) {
      return '${hours}h${remainingMinutes.toString().padLeft(2, '0')}min';
    }

    final days = hours ~/ 24;
    final remainingHours = hours % 24;
    return '${days}j ${remainingHours}h${remainingMinutes.toString().padLeft(2, '0')}min';
  }

  String _lastSignalLabel(BuildContext context) {
    final parsed = DateTime.tryParse(vehicle.lastSignalAt ?? '')?.toLocal();
    if (parsed == null) return '';
    final difference = DateTime.now().difference(parsed);
    if (difference.isNegative || difference.inSeconds < 5) {
      return context.tr('signal_just_now');
    }
    if (difference.inMinutes < 1) {
      return context.trFormat('signal_seconds_ago', {
        'count': difference.inSeconds,
      });
    }
    if (difference.inHours < 1) {
      return context.trFormat('signal_minutes_ago', {
        'count': difference.inMinutes,
      });
    }
    return context.trFormat('signal_hours_ago', {'count': difference.inHours});
  }
}

class _TrackingMetric extends StatelessWidget {
  const _TrackingMetric({
    required this.icon,
    required this.value,
    required this.color,
    this.circledIcon = false,
  });

  final IconData icon;
  final String value;
  final Color color;
  final bool circledIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (circledIcon)
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.4),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 12, color: color),
          )
        else
          Icon(icon, size: 17, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
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
