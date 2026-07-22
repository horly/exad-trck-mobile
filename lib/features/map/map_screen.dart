import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';
import '../../core/session/session_controller.dart';
import '../../shared/widgets/ui_components.dart';
import 'map_vehicle_sheets.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.session, required this.active});

  final SessionController session;
  final bool active;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  static const liveRefreshInterval = Duration(seconds: 10);
  static const markerAnimationDuration = Duration(seconds: 5);
  static const initialStreetZoom = 15.5;

  final searchController = TextEditingController();
  GoogleMapController? mapController;
  VehicleData? selectedVehicle;
  VehicleTripData? selectedTrip;
  List<VehicleData> liveVehicles = const [];
  final Map<int, LatLng> displayedPositions = {};
  final Map<int, _VehicleMotion> motions = {};
  final Map<_VehicleMarkerState, BitmapDescriptor> markerIcons = {};
  Timer? refreshTimer;
  Timer? animationTimer;
  String query = '';
  String statusFilter = 'all';
  bool panelVisible = true;
  bool myLocationEnabled = false;
  bool autoRefresh = true;
  bool refreshing = false;
  DateTime? lastUpdatedAt;
  DateTime? lastCameraFollowAt;

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
      WidgetsBinding.instance.addPostFrameCallback((_) => _startLiveRefresh());
    }
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    if (widget.active) {
      _startLiveRefresh();
    } else {
      refreshTimer?.cancel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.active) {
      _startLiveRefresh();
      return;
    }
    refreshTimer?.cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refreshTimer?.cancel();
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: ScreenTitle(
            title: context.tr('map'),
            subtitle: context.trFormat('positioned_vehicle_count', {
              'count': vehicles.length,
            }),
            trailing: IconButton.filledTonal(
              tooltip: context.tr('refresh'),
              onPressed: refreshing
                  ? null
                  : () => _refreshLive(showError: true),
              icon: refreshing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ),
        ),
        Expanded(
          child: vehicles.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(18),
                  child: SectionPanel(
                    child: EmptyState(
                      icon: Icons.location_off_outlined,
                      message: context.tr('no_position'),
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) =>
                      _buildMap(context, constraints, vehicles),
                ),
        ),
      ],
    );
  }

  Widget _buildMap(
    BuildContext context,
    BoxConstraints constraints,
    List<VehicleData> vehicles,
  ) {
    final compact = constraints.maxWidth < 720;
    final panelWidth = compact
        ? (constraints.maxWidth - 32).clamp(260.0, 330.0).toDouble()
        : 340.0;
    final selectedPanelLeft = panelVisible && !compact ? panelWidth + 32 : 16.0;

    return Stack(
      children: [
        Positioned.fill(
          child: GoogleMap(
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
            },
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          left: panelVisible ? 16 : -panelWidth - 12,
          top: 16,
          bottom: 16,
          width: panelWidth,
          child: _VehicleMapPanel(
            searchController: searchController,
            vehicles: filteredVehicles,
            summaryVehicles: positionedVehicles,
            selectedVehicle: selectedVehicle,
            statusFilter: statusFilter,
            autoRefresh: autoRefresh,
            refreshing: refreshing,
            lastUpdatedAt: lastUpdatedAt,
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
        AnimatedPositioned(
          duration: const Duration(milliseconds: 220),
          left: panelVisible ? panelWidth + 24 : 16,
          top: 16,
          child: _MapIconButton(
            tooltip: panelVisible
                ? context.tr('hide_map_menu')
                : context.tr('show_map_menu'),
            icon: panelVisible ? Icons.chevron_left : Icons.menu,
            onPressed: () => setState(() => panelVisible = !panelVisible),
          ),
        ),
        Positioned(
          right: 16,
          top: 16,
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
        if (selectedVehicle != null)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            left: selectedPanelLeft,
            right: 16,
            bottom: 16,
            child: _SelectedVehiclePanel(
              vehicle: selectedVehicle!,
              onClose: () => setState(() {
                selectedVehicle = null;
                selectedTrip = null;
              }),
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
    required this.searchController,
    required this.vehicles,
    required this.summaryVehicles,
    required this.selectedVehicle,
    required this.statusFilter,
    required this.autoRefresh,
    required this.refreshing,
    required this.lastUpdatedAt,
    required this.onSearch,
    required this.onStatusChanged,
    required this.onAutoRefreshChanged,
    required this.onSelect,
    required this.onClose,
  });

  final TextEditingController searchController;
  final List<VehicleData> vehicles;
  final List<VehicleData> summaryVehicles;
  final VehicleData? selectedVehicle;
  final String statusFilter;
  final bool autoRefresh;
  final bool refreshing;
  final DateTime? lastUpdatedAt;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<bool> onAutoRefreshChanged;
  final ValueChanged<VehicleData> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: const Color(0x220F172A),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
            child: Row(
              children: [
                Icon(
                  Icons.map_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('map_menu'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: context.tr('hide_map_menu'),
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _MapSummary(vehicles: summaryVehicles),
                const SizedBox(height: 12),
                TextField(
                  controller: searchController,
                  onChanged: onSearch,
                  decoration: InputDecoration(
                    hintText: context.tr('search_vehicle'),
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: statusFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('status'),
                    prefixIcon: const Icon(Icons.tune),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(context.tr('all')),
                    ),
                    DropdownMenuItem(
                      value: 'online',
                      child: Text(context.tr('online')),
                    ),
                    DropdownMenuItem(
                      value: 'moving',
                      child: Text(context.tr('moving_now')),
                    ),
                    DropdownMenuItem(
                      value: 'parking',
                      child: Text(context.tr('parking')),
                    ),
                    DropdownMenuItem(
                      value: 'offline',
                      child: Text(context.tr('offline')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onStatusChanged(value);
                  },
                ),
                const SizedBox(height: 8),
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
                    Text(
                      context.tr('live_tracking'),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    Switch(value: autoRefresh, onChanged: onAutoRefreshChanged),
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
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: vehicles.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      final selected = vehicle.id == selectedVehicle?.id;
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: selected
                              ? Theme.of(
                                  context,
                                ).colorScheme.secondary.withValues(alpha: .07)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: VehicleRow(
                          vehicle: vehicle,
                          onTap: () => onSelect(vehicle),
                        ),
                      );
                    },
                  ),
          ),
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

class _MapSummary extends StatelessWidget {
  const _MapSummary({required this.vehicles});

  final List<VehicleData> vehicles;

  @override
  Widget build(BuildContext context) {
    final stats = [
      (context.tr('all'), vehicles.length, const Color(0xFF2563EB)),
      (
        context.tr('online'),
        vehicles.where((vehicle) => vehicle.isOnline).length,
        const Color(0xFF07966F),
      ),
      (
        context.tr('moving'),
        vehicles.where((vehicle) => vehicle.isMoving).length,
        const Color(0xFF229BD8),
      ),
      (
        context.tr('offline'),
        vehicles.where((vehicle) => !vehicle.isOnline).length,
        const Color(0xFFE98A00),
      ),
    ];

    return Row(
      children: stats.map((stat) {
        return Expanded(
          child: Tooltip(
            message: stat.$1,
            child: Container(
              margin: EdgeInsets.only(right: stat == stats.last ? 0 : 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: stat.$3.withValues(alpha: .08),
                border: Border.all(color: stat.$3.withValues(alpha: .2)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${stat.$2}',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: stat.$3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stat.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
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
      color: Colors.white,
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
        style: style,
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
      color: Colors.white,
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
