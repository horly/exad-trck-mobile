import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/localization/app_localizations.dart';
import 'core/notifications/notification_controller.dart';
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
    this.notificationController,
  });

  final SessionController? sessionController;
  final LocaleController? localeController;
  final ThemeController? themeController;
  final NotificationController? notificationController;

  @override
  State<ExadTrackingApp> createState() => _ExadTrackingAppState();
}

class _ExadTrackingAppState extends State<ExadTrackingApp> {
  late final SessionController session;
  late final LocaleController localeController;
  late final ThemeController themeController;
  late final NotificationController notificationController;

  @override
  void initState() {
    super.initState();
    session = widget.sessionController ?? SessionController();
    localeController = widget.localeController ?? LocaleController();
    themeController = widget.themeController ?? ThemeController();
    notificationController =
        widget.notificationController ?? NotificationController();
    localeController.addListener(_syncApiLanguage);
    unawaited(_initializeControllers());
  }

  Future<void> _initializeControllers() async {
    if (widget.localeController == null) await localeController.initialize();
    _syncApiLanguage();

    await Future.wait([
      if (widget.themeController == null) themeController.initialize(),
      if (widget.notificationController == null)
        notificationController.initialize(),
    ]);

    if (widget.sessionController == null) await session.initialize();
  }

  void _syncApiLanguage() {
    final systemLanguage =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final languageCode =
        localeController.locale?.languageCode ?? systemLanguage;
    session.setLanguageCode(languageCode);
    notificationController.setLanguageCode(languageCode);
  }

  @override
  void dispose() {
    localeController.removeListener(_syncApiLanguage);
    session.dispose();
    localeController.dispose();
    themeController.dispose();
    notificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        session,
        localeController,
        themeController,
        notificationController,
      ]),
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
            SessionStage.booting => SplashScreen(
              message: session.message,
              onRetry: session.message == null ? null : session.initialize,
            ),
            SessionStage.signedOut => LoginScreen(
              session: session,
              localeController: localeController,
            ),
            SessionStage.twoFactor => TwoFactorScreen(session: session),
            SessionStage.signedIn => HomeShell(
              session: session,
              localeController: localeController,
              themeController: themeController,
              notifications: notificationController,
            ),
          },
        );
      },
    );
  }
}
