import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/localization/app_localizations.dart';
import 'core/session/session_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/two_factor_screen.dart';
import 'features/shell/home_shell.dart';

class ExadTrackingApp extends StatefulWidget {
  const ExadTrackingApp({
    super.key,
    this.sessionController,
    this.localeController,
    this.themeController,
  });

  final SessionController? sessionController;
  final LocaleController? localeController;
  final ThemeController? themeController;

  @override
  State<ExadTrackingApp> createState() => _ExadTrackingAppState();
}

class _ExadTrackingAppState extends State<ExadTrackingApp> {
  late final SessionController session;
  late final LocaleController localeController;
  late final ThemeController themeController;

  @override
  void initState() {
    super.initState();
    session = widget.sessionController ?? SessionController();
    localeController = widget.localeController ?? LocaleController();
    themeController = widget.themeController ?? ThemeController();
    if (widget.sessionController == null) session.initialize();
    if (widget.localeController == null) localeController.initialize();
    if (widget.themeController == null) themeController.initialize();
  }

  @override
  void dispose() {
    session.dispose();
    localeController.dispose();
    themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([session, localeController, themeController]),
      builder: (context, _) {
        return MaterialApp(
          title: session.branding.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.fromBranding(session.branding),
          darkTheme: AppTheme.fromBranding(
            session.branding,
            brightness: Brightness.dark,
          ),
          themeMode: themeController.mode,
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
              themeController: themeController,
            ),
          },
        );
      },
    );
  }
}
