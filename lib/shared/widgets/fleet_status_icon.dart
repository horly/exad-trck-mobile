import 'package:flutter/material.dart';

enum FleetStatusSymbol { online, offline, moving, parked }

/// A restrained, consistent icon badge for fleet supervision counters.
class FleetStatusIcon extends StatelessWidget {
  const FleetStatusIcon({super.key, required this.symbol, required this.color});

  final FleetStatusSymbol symbol;
  final Color color;

  IconData get _icon => switch (symbol) {
    FleetStatusSymbol.online => Icons.sensors_rounded,
    FleetStatusSymbol.offline => Icons.sensors_off_rounded,
    FleetStatusSymbol.moving => Icons.navigation_rounded,
    FleetStatusSymbol.parked => Icons.local_parking_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          shape: BoxShape.circle,
        ),
        child: Icon(_icon, size: 15, color: color),
      ),
    );
  }
}
