import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui_components.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  UserManagementData? _data;
  String? _error;
  String _search = '';
  bool _working = false;

  bool get _canManage => widget.session.user?.canManageUsers == true;

  @override
  void initState() {
    super.initState();
    if (_canManage) _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await widget.session.managedUsers();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = context.tr('data_unavailable'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('users'))),
      body: !_canManage
          ? EmptyState(
              icon: Icons.lock_outline,
              message: context.tr('user_management_forbidden'),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  ScreenTitle(
                    title: context.tr('user_management'),
                    subtitle: context.tr('user_management_help'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: context.tr('search_user'),
                    ),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                  const SizedBox(height: 12),
                  CorporateAddButton(
                    label: context.tr('new_user'),
                    icon: Icons.person_add_alt_1_outlined,
                    loading: _working,
                    onPressed: _data?.canCreate == true ? _edit : null,
                  ),
                  const SizedBox(height: 14),
                  if (_data == null && _error == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(36),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null)
                    SectionPanel(
                      child: Column(
                        children: [
                          EmptyState(
                            icon: Icons.cloud_off_outlined,
                            message: _error!,
                          ),
                          OutlinedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: Text(context.tr('retry')),
                          ),
                        ],
                      ),
                    )
                  else if (users.isEmpty)
                    EmptyState(
                      icon: Icons.people_outline,
                      message: context.tr('no_users'),
                    )
                  else
                    ...users.map(_userCard),
                ],
              ),
            ),
    );
  }

  List<ManagedUserData> get _filteredUsers {
    final normalized = _search.trim().toLowerCase();
    final users = _data?.users ?? const <ManagedUserData>[];
    if (normalized.isEmpty) return users;
    return users
        .where(
          (user) =>
              user.name.toLowerCase().contains(normalized) ||
              user.email.toLowerCase().contains(normalized) ||
              (user.phone ?? '').toLowerCase().contains(normalized) ||
              (user.fleet?.name ?? '').toLowerCase().contains(normalized),
        )
        .toList(growable: false);
  }

  Widget _userCard(ManagedUserData user) {
    final roleColor = user.role == 'admin'
        ? const Color(0xFF7C3AED)
        : user.role == 'superadmin'
        ? const Color(0xFFD97706)
        : const Color(0xFF2563EB);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: SectionPanel(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: roleColor.withValues(alpha: .11),
              child: Text(
                _initials(user.name),
                style: TextStyle(color: roleColor, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      StatusPill(
                        label: context.tr('role_${user.role}'),
                        color: roleColor,
                      ),
                      if (user.fleet != null)
                        StatusPill(
                          label: user.fleet!.name,
                          color: AppTheme.success,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (user.canUpdate || user.canDelete)
              PopupMenuButton<String>(
                tooltip: context.tr('actions'),
                onSelected: (value) {
                  if (value == 'edit') _edit(user);
                  if (value == 'delete') _delete(user);
                },
                itemBuilder: (_) => [
                  if (user.canUpdate)
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(context.tr('edit')),
                      ),
                    ),
                  if (user.canDelete)
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.delete_outline,
                          color: AppTheme.danger,
                        ),
                        title: Text(
                          context.tr('delete'),
                          style: const TextStyle(color: AppTheme.danger),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit([ManagedUserData? user]) async {
    final data = _data!;
    if (data.fleets.isEmpty || data.roles.isEmpty) {
      _showMessage(context.tr('no_active_fleet'));
      return;
    }

    final name = TextEditingController(text: user?.name);
    final email = TextEditingController(text: user?.email);
    final password = TextEditingController();
    final confirmation = TextEditingController();
    final phone = TextEditingController(text: user?.phone);
    final address = TextEditingController(text: user?.address);
    final formKey = GlobalKey<FormState>();
    var obscurePassword = true;
    var role = data.roles.contains(user?.role) ? user!.role : data.roles.first;
    var fleetId = data.fleets.any((fleet) => fleet.id == user?.fleet?.id)
        ? user!.fleet!.id
        : data.fleets.first.id;
    final permissions = <String>{...?user?.permissions};

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CorporateFormDialog(
          title: user == null
              ? context.tr('new_user')
              : context.tr('edit_user'),
          subtitle: context.tr('user_form_help'),
          icon: user == null
              ? Icons.person_add_alt_1_rounded
              : Icons.manage_accounts_rounded,
          formKey: formKey,
          cancelLabel: context.tr('cancel'),
          confirmLabel: context.tr('save'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _spaced([
              _requiredField(
                name,
                context.tr('full_name'),
                Icons.person_outline_rounded,
              ),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: corporateInputDecoration(
                  label: context.tr('email'),
                  icon: Icons.alternate_email_rounded,
                ),
                validator: _emailValidator,
              ),
              TextFormField(
                controller: password,
                obscureText: obscurePassword,
                decoration: corporateInputDecoration(
                  label: user == null
                      ? context.tr('password')
                      : context.tr('new_password_optional'),
                  icon: Icons.lock_outline_rounded,
                  helper: context.tr('password_rules'),
                  suffixIcon: IconButton(
                    onPressed: () => setDialogState(
                      () => obscurePassword = !obscurePassword,
                    ),
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) =>
                    _passwordValidator(value, required: user == null),
              ),
              TextFormField(
                controller: confirmation,
                obscureText: obscurePassword,
                decoration: corporateInputDecoration(
                  label: context.tr('confirm_password'),
                  icon: Icons.verified_user_outlined,
                ),
                validator: (value) => value == password.text
                    ? null
                    : context.tr('password_mismatch'),
              ),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: corporateInputDecoration(
                  label: context.tr('role'),
                  icon: Icons.badge_outlined,
                ),
                items: data.roles
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(context.tr('role_$value')),
                      ),
                    )
                    .toList(),
                onChanged: data.roles.length == 1
                    ? null
                    : (value) => setDialogState(() {
                        role = value ?? role;
                        if (role == 'admin') permissions.clear();
                      }),
              ),
              DropdownButtonFormField<int>(
                initialValue: fleetId,
                isExpanded: true,
                decoration: corporateInputDecoration(
                  label: context.tr('fleet'),
                  icon: Icons.corporate_fare_outlined,
                ),
                items: data.fleets
                    .map(
                      (fleet) => DropdownMenuItem(
                        value: fleet.id,
                        child: Text('${fleet.name} · ${fleet.code}'),
                      ),
                    )
                    .toList(),
                onChanged: data.fleets.length == 1
                    ? null
                    : (value) => fleetId = value ?? fleetId,
              ),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: corporateInputDecoration(
                  label: context.tr('phone'),
                  icon: Icons.phone_outlined,
                ),
              ),
              TextFormField(
                controller: address,
                minLines: 2,
                maxLines: 3,
                decoration: corporateInputDecoration(
                  label: context.tr('address'),
                  icon: Icons.location_on_outlined,
                ),
              ),
              if (role == 'user')
                SectionPanel(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 9),
                          Text(
                            context.tr('account_permissions'),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...data.permissions.map(
                        (permission) => CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: permissions.contains(permission),
                          title: Text(_permissionLabel(permission)),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (checked) => setDialogState(() {
                            checked == true
                                ? permissions.add(permission)
                                : permissions.remove(permission);
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
            ]),
          ),
        ),
      ),
    );

    if (saved != true) return;
    await _run(
      () => widget.session.saveManagedUser(
        id: user?.id,
        name: name.text.trim(),
        email: email.text.trim(),
        role: role,
        fleetId: fleetId,
        permissions: role == 'user' ? permissions.toList() : const [],
        password: password.text.isEmpty ? null : password.text,
        phone: _nullable(phone.text),
        address: _nullable(address.text),
      ),
    );
  }

  Future<void> _delete(ManagedUserData user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('delete_user')),
        content: Text(
          context.tr('delete_user_confirmation').replaceAll(':name', user.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _run(() => widget.session.deleteManagedUser(user.id));
    }
  }

  Future<void> _run(Future<String> Function() operation) async {
    setState(() => _working = true);
    final fallbackMessage = context.tr('saved_successfully');
    try {
      final message = await operation();
      _showMessage(message.isEmpty ? fallbackMessage : message);
      await _load();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  TextFormField _requiredField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) => TextFormField(
    controller: controller,
    decoration: corporateInputDecoration(label: label, icon: icon),
    validator: (value) =>
        value == null || value.trim().isEmpty ? context.tr('required') : null,
  );

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return context.tr('required');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return context.tr('invalid_email');
    }
    return null;
  }

  String? _passwordValidator(String? value, {required bool required}) {
    final password = value ?? '';
    if (password.isEmpty) return required ? context.tr('required') : null;
    final valid =
        password.length >= 12 &&
        RegExp('[a-z]').hasMatch(password) &&
        RegExp('[A-Z]').hasMatch(password) &&
        RegExp('[0-9]').hasMatch(password) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(password);
    return valid ? null : context.tr('password_rules');
  }

  List<Widget> _spaced(List<Widget> fields) => [
    for (var index = 0; index < fields.length; index++) ...[
      fields[index],
      if (index < fields.length - 1) const SizedBox(height: 12),
    ],
  ];

  String _permissionLabel(String permission) => switch (permission) {
    'map.view' => context.tr('permission_map_view'),
    'reports.generate' => context.tr('permission_reports'),
    'engine.control' => context.tr('permission_engine_control'),
    'garages.manage' => context.tr('permission_garages'),
    'maintenance.manage' => context.tr('permission_maintenance'),
    _ => permission,
  };

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
