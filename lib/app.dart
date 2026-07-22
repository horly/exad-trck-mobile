import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/localization/app_localizations.dart';
import 'core/session/session_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/two_factor_screen.dart';
import 'features/shell/home_shell.dart';

class ExadTrackingApp extends StatefulWidget {
  const ExadTrackingApp({
    super.key,
    this.sessionController,
    this.localeController,
  });

  final SessionController? sessionController;
  final LocaleController? localeController;

  @override
  State<ExadTrackingApp> createState() => _ExadTrackingAppState();
}

class _ExadTrackingAppState extends State<ExadTrackingApp> {
  late final SessionController session;
  late final LocaleController localeController;

  @override
  void initState() {
    super.initState();
    session = widget.sessionController ?? SessionController();
    localeController = widget.localeController ?? LocaleController();
    if (widget.sessionController == null) session.initialize();
    if (widget.localeController == null) localeController.initialize();
  }

  @override
  void dispose() {
    session.dispose();
    localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([session, localeController]),
      builder: (context, _) {
        return MaterialApp(
          title: session.branding.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.fromBranding(session.branding),
          locale: localeController.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: switch (session.stage) {
            SessionStage.booting => const SplashScreen(),
            SessionStage.signedOut => LoginScreen(
              session: session,
              localeController: localeController,
            ),
            SessionStage.twoFactor => TwoFactorScreen(session: session),
            SessionStage.signedIn => HomeShell(
              session: session,
              localeController: localeController,
            ),
          },
        );
      },
    );
  }
}
