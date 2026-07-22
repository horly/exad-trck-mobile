import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/exad_logo.dart';

class TwoFactorScreen extends StatefulWidget {
  const TwoFactorScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final recovery = session.useRecoveryCode;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: context.tr('back'),
          onPressed: session.cancelTwoFactor,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: ExadLogo(height: 48),
              ),
              const SizedBox(height: 48),
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.tr('two_factor'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                recovery
                    ? context.tr('recovery_help')
                    : context.tr('two_factor_code_help'),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: recovery
                    ? TextInputType.text
                    : TextInputType.number,
                inputFormatters: recovery
                    ? const []
                    : [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                decoration: InputDecoration(
                  labelText: recovery
                      ? context.tr('recovery_code')
                      : context.tr('security_code'),
                  prefixIcon: const Icon(Icons.password_outlined),
                  errorText:
                      session.fieldErrors[recovery ? 'recovery_code' : 'code'],
                ),
                onSubmitted: (_) => session.verifyTwoFactor(controller.text),
              ),
              if (session.message != null) ...[
                const SizedBox(height: 10),
                Text(
                  session.message!,
                  style: const TextStyle(color: AppTheme.danger),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: session.busy
                    ? null
                    : () => session.verifyTwoFactor(controller.text),
                icon: const Icon(Icons.verified_outlined),
                label: Text(context.tr('verify')),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  controller.clear();
                  session.toggleRecoveryCode();
                },
                child: Text(
                  recovery
                      ? context.tr('use_temporary')
                      : context.tr('use_recovery'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
