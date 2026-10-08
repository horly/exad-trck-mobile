import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';

class FuelLevelBadge extends StatelessWidget {
  const FuelLevelBadge({super.key, required this.fuel, this.compact = false});

  final VehicleFuelData fuel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    final label = '${context.tr('fuel_level')} : ${fuel.label(language)}';
    final color = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_gas_station_rounded,
              size: compact ? 13 : 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                fuel.label(language, compact: compact),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: compact ? 10 : 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
