import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/updates/app_update_service.dart';

class AppUpdateBanner extends StatefulWidget {
  const AppUpdateBanner({super.key, this.service = const AppUpdateService()});
  final AppUpdateService service;

  @override
  State<AppUpdateBanner> createState() => _AppUpdateBannerState();
}

class _AppUpdateBannerState extends State<AppUpdateBanner>
    with WidgetsBindingObserver {
  int? availableBuild;
  bool checking = false, opening = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(check());
    timer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(check());
      }
    });
  }

  Future<void> check() async {
    if (checking) return;
    checking = true;
    final build = await widget.service.availableBuild();
    if (mounted) setState(() => availableBuild = build);
    checking = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(check());
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> openStore() async {
    setState(() => opening = true);
    final opened = await widget.service.openStore();
    if (!mounted) return;
    setState(() => opening = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('update_store_failed'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (availableBuild == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.primary.withValues(alpha: .2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.system_update_rounded,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('update_available'),
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('update_available_hint'),
              style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 12),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: opening ? null : openStore,
              icon: const Icon(Icons.shop_outlined, size: 18),
              label: Text(context.tr('update_open_store')),
            ),
          ],
        ),
      ),
    );
  }
}
