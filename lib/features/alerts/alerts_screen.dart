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
          Material(
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              value: onlyNew,
              onChanged: (value) => setState(() => onlyNew = value),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.mark_email_unread_outlined,
                  size: 19,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              title: Text(
                context.tr('only_new_alerts'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (alerts.isEmpty)
            SectionPanel(
              child: EmptyState(
                icon: Icons.notifications_none,
                message: context.tr('no_alert_selection'),
              ),
            )
          else
            ...alerts.map(
              (alert) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CorporateAlertRow(alert: alert),
              ),
            ),
        ],
      ),
    );
  }
}
