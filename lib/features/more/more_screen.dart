import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/exad_logo.dart';
import '../../shared/widgets/ui_components.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.session,
    required this.localeController,
  });

  final SessionController session;
  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    final user = session.user;
    final superadmin = user?.isSuperadmin == true;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        ScreenTitle(
          title: context.tr('more'),
          subtitle: context.tr('account_access'),
        ),
        const SizedBox(height: 20),
        SectionPanel(
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: superadmin
                        ? const Color(0xFF0B1746)
                        : session.branding.primary,
                    foregroundColor: Colors.white,
                    child: Text(user?.initials ?? 'U'),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '-',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user?.email ?? '-',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (superadmin)
                    const Icon(
                      Icons.admin_panel_settings,
                      color: Color(0xFF1D4ED8),
                    ),
                ],
              ),
              const Divider(height: 30),
              _InfoLine(
                icon: Icons.badge_outlined,
                label: context.tr('role'),
                value: user?.role ?? '-',
              ),
              _InfoLine(
                icon: Icons.local_shipping_outlined,
                label: context.tr('fleet'),
                value: superadmin
                    ? context.tr('global_overview')
                    : user?.fleet?.name ?? context.tr('unassigned'),
              ),
              _InfoLine(
                icon: Icons.verified_user_outlined,
                label: context.tr('two_factor_short'),
                value: user?.twoFactorEnabled == true
                    ? context.tr('enabled')
                    : context.tr('disabled'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('settings'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: session.branding.secondary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.language,
                    color: session.branding.secondary,
                  ),
                ),
                title: Text(context.tr('language')),
                subtitle: Text(_localeLabel(context)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguagePicker(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SectionPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('authorized_access'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    user?.permissions.entries
                        .where((entry) => entry.value)
                        .map(
                          (entry) => Chip(
                            label: Text(_permissionLabel(context, entry.key)),
                          ),
                        )
                        .toList() ??
                    const [],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: session.busy ? null : session.logout,
          icon: const Icon(Icons.logout, color: AppTheme.danger),
          label: Text(
            context.tr('logout'),
            style: const TextStyle(color: AppTheme.danger),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: AppTheme.danger),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 34),
        const Center(child: ExadLogo(height: 35)),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'EXAD Tracking mobile · v1.0.0',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  String _localeLabel(BuildContext context) {
    if (localeController.locale == null) return context.tr('system_language');
    return localeController.locale!.languageCode == 'en'
        ? context.tr('english')
        : context.tr('french');
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.phone_android),
                title: Text(context.tr('system_language')),
                trailing: localeController.locale == null
                    ? const Icon(Icons.check)
                    : null,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await localeController.useSystemLocale();
                },
              ),
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(context.tr('french')),
                trailing: localeController.locale?.languageCode == 'fr'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await localeController.setLocale(const Locale('fr'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(context.tr('english')),
                trailing: localeController.locale?.languageCode == 'en'
                    ? const Icon(Icons.check)
                    : null,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await localeController.setLocale(const Locale('en'));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _permissionLabel(BuildContext context, String permission) {
    return switch (permission) {
      'map_view' => context.tr('map'),
      'reports_generate' => 'Rapports',
      'garages_manage' => 'Garages',
      'maintenance_manage' => 'Entretiens',
      _ => permission.replaceAll('_', ' '),
    };
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.secondary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
