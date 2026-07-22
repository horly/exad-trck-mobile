import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/exad_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.session,
    required this.localeController,
  });

  final SessionController session;
  final LocaleController localeController;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  bool submitted = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() => submitted = true);
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      return;
    }
    await widget.session.login(emailController.text, passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final emailError = session.fieldErrors['email'];
    final passwordError = session.fieldErrors['password'];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF071A3B),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: constraints.maxHeight < 700 ? 248 : 300,
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: CustomPaint(
                                painter: _LoginBackdropPainter(),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                18,
                                24,
                                22,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const ExadLogo(height: 50, inverse: true),
                                      const Spacer(),
                                      _LanguageButton(
                                        localeController:
                                            widget.localeController,
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    context.tr('mobile_platform'),
                                    style: const TextStyle(
                                      color: Color(0xFF65C8FF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'EXAD Tracking',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontSize: 28,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 310,
                                    child: Text(
                                      context.tr('mobile_value'),
                                      style: const TextStyle(
                                        color: Color(0xFFD8E7FF),
                                        fontSize: 13,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        constraints: BoxConstraints(
                          minHeight:
                              constraints.maxHeight -
                              (constraints.maxHeight < 700 ? 248 : 300),
                        ),
                        decoration: const BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: session.branding.secondary
                                        .withValues(alpha: .1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.shield_outlined,
                                    color: session.branding.secondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr('secure_area'),
                                        style: TextStyle(
                                          color: session.branding.secondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        context.tr('login'),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            Text(
                              context.tr('login_subtitle'),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 22),
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              onChanged: (_) => session.clearErrors(),
                              decoration: InputDecoration(
                                labelText: context.tr('email'),
                                hintText: context.tr('email_hint'),
                                prefixIcon: const Icon(Icons.mail_outline),
                                errorText:
                                    emailError ??
                                    (submitted &&
                                            emailController.text.trim().isEmpty
                                        ? context.tr('email_required')
                                        : null),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: passwordController,
                              obscureText: obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              onChanged: (_) => session.clearErrors(),
                              onSubmitted: (_) => submit(),
                              decoration: InputDecoration(
                                labelText: context.tr('password'),
                                prefixIcon: const Icon(Icons.lock_outline),
                                errorText:
                                    passwordError ??
                                    (submitted &&
                                            passwordController.text.isEmpty
                                        ? context.tr('password_required')
                                        : null),
                                suffixIcon: IconButton(
                                  tooltip: obscurePassword
                                      ? context.tr('show')
                                      : context.tr('hide'),
                                  onPressed: () => setState(
                                    () => obscurePassword = !obscurePassword,
                                  ),
                                  icon: Icon(
                                    obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                            if (session.message != null &&
                                emailError == null &&
                                passwordError == null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger.withValues(alpha: .08),
                                  border: Border.all(
                                    color: AppTheme.danger.withValues(
                                      alpha: .35,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  session.message!,
                                  style: const TextStyle(
                                    color: AppTheme.danger,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: session.busy ? null : submit,
                              icon: session.busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.login),
                              label: Text(context.tr('sign_in')),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.lock_outline,
                                  color: AppTheme.success,
                                  size: 17,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    context.tr('secure_connection'),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({required this.localeController});

  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    final current = Localizations.localeOf(context).languageCode.toUpperCase();
    return OutlinedButton.icon(
      onPressed: () => _showLanguagePicker(context),
      icon: const Icon(Icons.language, size: 18),
      label: Text(current),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF4A638B)),
        minimumSize: const Size(76, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Text(
                  context.tr('language'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _LanguageOption(
                icon: Icons.phone_android,
                label: context.tr('system_language'),
                selected: localeController.locale == null,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await localeController.useSystemLocale();
                },
              ),
              _LanguageOption(
                icon: Icons.translate,
                label: context.tr('french'),
                selected: localeController.locale?.languageCode == 'fr',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await localeController.setLocale(const Locale('fr'));
                },
              ),
              _LanguageOption(
                icon: Icons.translate,
                label: context.tr('english'),
                selected: localeController.locale?.languageCode == 'en',
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
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppTheme.success)
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _LoginBackdropPainter extends CustomPainter {
  const _LoginBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF1E4B83)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final accentPaint = Paint()..color = const Color(0xFF31B5F5);

    final paths = [
      Path()
        ..moveTo(size.width * .35, size.height * .1)
        ..quadraticBezierTo(
          size.width * .62,
          size.height * .22,
          size.width * .9,
          size.height * .06,
        ),
      Path()
        ..moveTo(size.width * .44, size.height * .38)
        ..quadraticBezierTo(
          size.width * .72,
          size.height * .22,
          size.width * 1.05,
          size.height * .48,
        ),
      Path()
        ..moveTo(size.width * .58, size.height * .66)
        ..quadraticBezierTo(
          size.width * .72,
          size.height * .48,
          size.width,
          size.height * .68,
        ),
    ];
    for (final path in paths) {
      canvas.drawPath(path, linePaint);
    }
    for (final point in [
      Offset(size.width * .58, size.height * .18),
      Offset(size.width * .78, size.height * .16),
      Offset(size.width * .72, size.height * .44),
      Offset(size.width * .91, size.height * .36),
    ]) {
      canvas.drawCircle(point, 3, accentPaint);
      canvas.drawCircle(
        point,
        8,
        Paint()
          ..color = const Color(0x5531B5F5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
