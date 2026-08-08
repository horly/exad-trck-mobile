import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../shared/widgets/exad_logo.dart';
import '../../shared/widgets/ui_components.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    super.key,
    required this.session,
    required this.localeController,
    required this.themeController,
  });

  final SessionController session;
  final LocaleController localeController;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    final user = session.user;
    final superadmin = user?.isSuperadmin == true;
    final primary = superadmin
        ? const Color(0xFF0B1746)
        : session.branding.primary;
    final permissions =
        user?.permissions.entries.where((entry) => entry.value).toList() ??
        const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        ScreenTitle(
          title: context.tr('more'),
          subtitle: context.tr('account_access'),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, Color.lerp(primary, Colors.black, .22)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: .18),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .28),
                        ),
                      ),
                      child: Text(
                        user?.initials ?? 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            user?.email ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .72),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        superadmin
                            ? Icons.admin_panel_settings_outlined
                            : Icons.verified_user_outlined,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Divider(color: Colors.white.withValues(alpha: .16), height: 1),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: _ProfileMeta(
                        label: context.tr('role'),
                        value: user?.role ?? '-',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: Colors.white.withValues(alpha: .16),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _ProfileMeta(
                        label: context.tr('two_factor_short'),
                        value: user?.twoFactorEnabled == true
                            ? context.tr('enabled')
                            : context.tr('disabled'),
                        statusColor: user?.twoFactorEnabled == true
                            ? const Color(0xFF5EEAC4)
                            : const Color(0xFFFFC76B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SectionPanel(
          padding: const EdgeInsets.all(14),
          child: _InfoLine(
            icon: Icons.local_shipping_outlined,
            label: context.tr('fleet'),
            value: superadmin
                ? context.tr('global_overview')
                : user?.fleet?.name ?? context.tr('unassigned'),
          ),
        ),
        const SizedBox(height: 16),
        SectionPanel(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                icon: Icons.tune_rounded,
                title: context.tr('settings'),
              ),
              const SizedBox(height: 12),
              _SettingsRow(
                icon: Icons.language_rounded,
                title: context.tr('language'),
                value: _localeLabel(context),
                color: session.branding.secondary,
                onTap: () => _showLanguagePicker(context),
              ),
              const SizedBox(height: 8),
              _SettingsRow(
                icon: _themeIcon,
                title: context.tr('appearance'),
                value: _themeLabel(context),
                color: const Color(0xFF7C3AED),
                onTap: () => _showThemePicker(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionPanel(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                icon: Icons.key_outlined,
                title: context.tr('authorized_access'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: permissions
                    .map(
                      (entry) => _PermissionBadge(
                        label: _permissionLabel(context, entry.key),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: session.busy ? null : session.logout,
          icon: session.busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded, size: 18),
          label: Text(
            context.tr('logout'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.danger,
            minimumSize: const Size.fromHeight(48),
            side: BorderSide(color: AppTheme.danger.withValues(alpha: .55)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Center(
          child: ExadLogo(
            height: 29,
            inverse: Theme.of(context).brightness == Brightness.dark,
          ),
        ),
        const SizedBox(height: 7),
        Center(
          child: Text(
            'EXAD Tracking mobile · v${AppConfig.appVersion} '
            '(${AppConfig.appBuildNumber})',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
            ),
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

  IconData get _themeIcon => switch (themeController.mode) {
    ThemeMode.light => Icons.light_mode_rounded,
    ThemeMode.dark => Icons.dark_mode_rounded,
    ThemeMode.system => Icons.brightness_auto_rounded,
  };

  String _themeLabel(BuildContext context) => switch (themeController.mode) {
    ThemeMode.light => context.tr('theme_light'),
    ThemeMode.dark => context.tr('theme_dark'),
    ThemeMode.system => context.tr('theme_system'),
  };

  void _showThemePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  context.tr('choose_appearance'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _ThemeChoice(
                icon: Icons.brightness_auto_rounded,
                label: context.tr('theme_system'),
                selected: themeController.mode == ThemeMode.system,
                onSelected: () => _selectTheme(sheetContext, ThemeMode.system),
              ),
              _ThemeChoice(
                icon: Icons.light_mode_rounded,
                label: context.tr('theme_light'),
                selected: themeController.mode == ThemeMode.light,
                onSelected: () => _selectTheme(sheetContext, ThemeMode.light),
              ),
              _ThemeChoice(
                icon: Icons.dark_mode_rounded,
                label: context.tr('theme_dark'),
                selected: themeController.mode == ThemeMode.dark,
                onSelected: () => _selectTheme(sheetContext, ThemeMode.dark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectTheme(BuildContext sheetContext, ThemeMode mode) async {
    Navigator.pop(sheetContext);
    await themeController.setMode(mode);
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

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: .42),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return ListTile(
      leading: Icon(icon, color: selected ? color : null),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: color)
          : null,
      selected: selected,
      onTap: onSelected,
    );
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
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.secondary,
            size: 19,
          ),
        ),
        const SizedBox(width: 11),
        Text(
          label,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 11.5,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileMeta extends StatelessWidget {
  const _ProfileMeta({
    required this.label,
    required this.value,
    this.statusColor,
  });

  final String label;
  final String value;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: .55),
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (statusColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PermissionBadge extends StatelessWidget {
  const _PermissionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .065),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .17)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
