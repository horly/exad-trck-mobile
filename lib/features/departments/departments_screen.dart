import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui_components.dart';

typedef DepartmentLoader = Future<DepartmentCollectionData> Function();

class DepartmentsScreen extends StatefulWidget {
  const DepartmentsScreen({
    super.key,
    required this.session,
    this.loadDepartments,
  });

  final SessionController session;
  final DepartmentLoader? loadDepartments;

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  DepartmentCollectionData? _data;
  String? _error;
  String _query = '';
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data =
          await (widget.loadDepartments?.call() ??
              widget.session.departments());
      if (mounted) setState(() => _data = data);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = context.tr('data_unavailable'));
    }
  }

  List<DepartmentData> get _departments {
    final query = _query.trim().toLowerCase();
    final values = _data?.departments ?? const <DepartmentData>[];
    if (query.isEmpty) return values;
    return values
        .where(
          (department) => [
            department.name,
            department.code,
            department.description,
            department.fleet?.name,
          ].whereType<String>().join(' ').toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final departments = _departments;
    final canManage = _data?.canManage == true;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('departments'))),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _working ? null : () => _openEditor(),
              icon: const Icon(Icons.add),
              label: Text(context.tr('new_department')),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
          children: [
            ScreenTitle(
              title: context.tr('departments'),
              subtitle: context.trFormat('department_count', {
                'count': _data?.departments.length ?? 0,
              }),
            ),
            const SizedBox(height: 18),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: context.tr('search_department'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 18),
            if (_data == null && _error == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              SectionPanel(
                child: EmptyState(
                  icon: Icons.cloud_off_outlined,
                  message: _error!,
                ),
              )
            else if (departments.isEmpty)
              SectionPanel(
                child: EmptyState(
                  icon: Icons.apartment_outlined,
                  message: context.tr('no_department'),
                ),
              )
            else
              ...departments.map(
                (department) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DepartmentCard(
                    department: department,
                    canManage: canManage,
                    canDelete:
                        _data?.canDelete == true &&
                        department.driversCount == 0,
                    onEdit: () => _openEditor(department),
                    onDelete: () => _delete(department),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor([DepartmentData? department]) async {
    final data = _data;
    if (data == null || !data.canManage) return;
    final name = TextEditingController(text: department?.name ?? '');
    final code = TextEditingController(text: department?.code ?? '');
    final description = TextEditingController(
      text: department?.description ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var active = department?.isActive ?? true;
    var fleetId =
        department?.fleet?.id ??
        widget.session.user?.fleet?.id ??
        data.fleets.firstOrNull?.id;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            context.tr(
              department == null ? 'new_department' : 'edit_department',
            ),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.session.user?.isSuperadmin == true) ...[
                      DropdownButtonFormField<int>(
                        initialValue: fleetId,
                        decoration: InputDecoration(
                          labelText: context.tr('fleet'),
                        ),
                        items: data.fleets
                            .map(
                              (fleet) => DropdownMenuItem(
                                value: fleet.id,
                                child: Text(fleet.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => fleetId = value,
                        validator: (value) =>
                            value == null ? context.tr('required') : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: context.tr('department_name'),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? context.tr('required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: code,
                      decoration: InputDecoration(
                        labelText: context.tr('department_code'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: description,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: context.tr('description'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr('active')),
                      value: active,
                      onChanged: (value) =>
                          setDialogState(() => active = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('cancel')),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate() && fleetId != null) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: Text(context.tr('save')),
            ),
          ],
        ),
      ),
    );
    if (saved != true || fleetId == null) return;
    await _run(() async {
      final message = await widget.session.saveDepartment(
        id: department?.id,
        fleetId: fleetId!,
        name: name.text.trim(),
        code: _nullable(code.text),
        description: _nullable(description.text),
        status: active ? 'active' : 'inactive',
      );
      _showMessage(message);
    });
  }

  Future<void> _delete(DepartmentData department) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('delete_department_title')),
        content: Text(context.tr('delete_department_help')),
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
    if (confirmed != true) return;
    await _run(
      () async =>
          _showMessage(await widget.session.deleteDepartment(department.id)),
    );
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _working = true);
    try {
      await operation();
      await _load();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showMessage(String message) {
    if (mounted && message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({
    required this.department,
    required this.canManage,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final DepartmentData department;
  final bool canManage;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = department.isActive ? AppTheme.success : AppTheme.muted;
    return SectionPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.apartment_outlined,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      department.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (department.code?.trim().isNotEmpty == true)
                      Text(
                        department.code!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              StatusPill(
                label: context.tr(department.isActive ? 'active' : 'inactive'),
                color: statusColor,
              ),
              if (canManage)
                IconButton(
                  tooltip: context.tr('edit_department'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              if (canDelete)
                IconButton(
                  tooltip: context.tr('delete'),
                  color: AppTheme.danger,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          if (department.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(department.description!),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.local_shipping_outlined,
                label: department.fleet?.name ?? '-',
              ),
              _MetaChip(
                icon: Icons.badge_outlined,
                label: context.trFormat('drivers_count', {
                  'count': department.driversCount,
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
