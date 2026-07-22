import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/session/session_controller.dart';
import '../../shared/widgets/ui_components.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool onlyNew = false;

  @override
  Widget build(BuildContext context) {
    final alerts = widget.session.alerts
        .where((alert) => !onlyNew || alert.status == 'new')
        .toList();
    return RefreshIndicator(
      onRefresh: widget.session.refreshWorkspace,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          ScreenTitle(
            title: context.tr('alerts'),
            subtitle: context.trFormat('new_alert_count', {
              'count': widget.session.dashboard.newAlerts,
            }),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            value: onlyNew,
            onChanged: (value) => setState(() => onlyNew = value),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(context.tr('only_new_alerts')),
          ),
          const SizedBox(height: 8),
          SectionPanel(
            child: alerts.isEmpty
                ? EmptyState(
                    icon: Icons.notifications_none,
                    message: context.tr('no_alert_selection'),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < alerts.length; i++) ...[
                        AlertRow(alert: alerts[i]),
                        if (i < alerts.length - 1) const Divider(height: 1),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
