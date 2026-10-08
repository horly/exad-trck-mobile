import 'package:flutter/material.dart';
import '../../core/models/app_models.dart';

Color vehicleMarkerColor(VehicleData vehicle) {
  if (!vehicle.isOnline) return const Color(0xFFEF4444);
  if (vehicle.isMoving) return const Color(0xFF10B981);
  if (vehicle.isParking) return const Color(0xFF22A7DF);
  if (vehicle.isStationaryRunning) return const Color(0xFF229BD8);
  return const Color(0xFF10B981);
}

IconData vehicleMarkerIcon(VehicleData vehicle) {
  if (!vehicle.isOnline) return Icons.directions_car_filled_outlined;
  if (vehicle.isMoving) return Icons.navigation_rounded;
  if (vehicle.isParking) return Icons.local_parking_rounded;
  if (vehicle.isStationaryRunning) return Icons.pause_rounded;
  return Icons.directions_car_filled_outlined;
}
