import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/ui_components.dart';

enum _ManagementView { fleets, vehicles, trackers }

class FleetManagementScreen extends StatefulWidget {
  const FleetManagementScreen({super.key, required this.session});

  final SessionController session;

  @override
  State<FleetManagementScreen> createState() => _FleetManagementScreenState();
}

class _FleetManagementScreenState extends State<FleetManagementScreen> {
  FleetManagementData? _data;
  String? _error;
  bool _working = false;
  _ManagementView _view = _ManagementView.fleets;

  bool get _canAccess => _availableViews.isNotEmpty;

  List<_ManagementView> get _availableViews => [
    if (widget.session.user?.canManageFleets == true) _ManagementView.fleets,
    if (widget.session.user?.canManageVehicles == true)
      _ManagementView.vehicles,
    if (widget.session.user?.canManageTrackers == true)
      _ManagementView.trackers,
  ];

  @override
  void initState() {
    super.initState();
    if (_canAccess) {
      _view = _availableViews.first;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await widget.session.fleetManagement();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = context.tr('data_unavailable'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('fleet_management'))),
      body: !_canAccess
          ? EmptyState(
              icon: Icons.lock_outline,
              message: context.tr('management_superadmin_only'),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  ScreenTitle(
                    title: context.tr('fleet_management'),
                    subtitle: context.tr('fleet_management_help'),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<_ManagementView>(
                    segments: _availableViews
                        .map(
                          (view) => ButtonSegment(
                            value: view,
                            icon: Icon(_viewIcon(view)),
                            label: Text(_viewLabel(context, view)),
                          ),
                        )
                        .toList(),
                    selected: {_view},
                    showSelectedIcon: false,
                    onSelectionChanged: _working
                        ? null
                        : (value) => setState(() => _view = value.first),
                  ),
                  const SizedBox(height: 14),
                  CorporateAddButton(
                    label: _createLabel(context),
                    loading: _working,
                    onPressed: _data == null ? null : _create,
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
                  else
                    ..._content(context, _data!),
                ],
              ),
            ),
    );
  }

  List<Widget> _content(BuildContext context, FleetManagementData data) {
    return switch (_view) {
      _ManagementView.fleets =>
        data.fleets
            .map(
              (fleet) => _ManagementCard(
                icon: Icons.corporate_fare_outlined,
                title: fleet.name,
                subtitle:
                    '${fleet.code} · ${fleet.vehiclesCount} ${context.tr('vehicles').toLowerCase()}${fleet.manager == null ? '' : ' · ${fleet.manager!.name}'}',
                status: context.tr(fleet.status),
                statusColor: fleet.status == 'active'
                    ? AppTheme.success
                    : AppTheme.warning,
                color: const Color(0xFF315CCB),
                onEdit: () => _editFleet(fleet),
                onDelete: () => _deleteFleet(fleet),
              ),
            )
            .toList(),
      _ManagementView.vehicles =>
        data.vehicles
            .map(
              (vehicle) => _ManagementCard(
                icon: Icons.directions_car_outlined,
                title: vehicle.name,
                subtitle:
                    '${vehicle.registration} · ${vehicle.fleet?.name ?? context.tr('unassigned')}',
                status: vehicle.trackingConfigured
                    ? context.tr('configured')
                    : context.tr('not_configured'),
                statusColor: vehicle.trackingConfigured
                    ? AppTheme.success
                    : AppTheme.warning,
                color: const Color(0xFF0B9BCB),
                onEdit: () => _editVehicle(vehicle),
                onDelete: () => _deleteVehicle(vehicle),
              ),
            )
            .toList(),
      _ManagementView.trackers =>
        data.trackers
            .map(
              (tracker) => _ManagementCard(
                icon: Icons.sensors_outlined,
                title: tracker.name?.trim().isNotEmpty == true
                    ? tracker.name!
                    : tracker.model,
                subtitle:
                    '${tracker.imei} · ${tracker.vehicle?.name ?? context.tr('unassigned')}',
                status: context.tr(tracker.status),
                statusColor:
                    tracker.status == 'online' || tracker.status == 'active'
                    ? AppTheme.success
                    : AppTheme.warning,
                color: const Color(0xFF6D4BD1),
                onEdit: () => _editTracker(tracker),
                onDelete: () => _deleteTracker(tracker),
              ),
            )
            .toList(),
    };
  }

  String _createLabel(BuildContext context) => switch (_view) {
    _ManagementView.fleets => context.tr('new_fleet'),
    _ManagementView.vehicles => context.tr('new_vehicle'),
    _ManagementView.trackers => context.tr('new_tracker'),
  };

  String _viewLabel(BuildContext context, _ManagementView view) =>
      switch (view) {
        _ManagementView.fleets => context.tr('fleets'),
        _ManagementView.vehicles => context.tr('vehicles'),
        _ManagementView.trackers => context.tr('trackers'),
      };

  IconData _viewIcon(_ManagementView view) => switch (view) {
    _ManagementView.fleets => Icons.corporate_fare_outlined,
    _ManagementView.vehicles => Icons.directions_car_outlined,
    _ManagementView.trackers => Icons.sensors_outlined,
  };

  Future<void> _create() async {
    switch (_view) {
      case _ManagementView.fleets:
        return _createFleet();
      case _ManagementView.vehicles:
        return _createVehicle();
      case _ManagementView.trackers:
        return _createTracker();
    }
  }

  Future<void> _createFleet() => _saveFleet();

  Future<void> _editFleet(ManagedFleetData fleet) => _saveFleet(fleet);

  Future<void> _saveFleet([ManagedFleetData? fleet]) async {
    final data = _data!;
    final name = TextEditingController(text: fleet?.name);
    final code = TextEditingController(text: fleet?.code);
    final description = TextEditingController(text: fleet?.description);
    final key = GlobalKey<FormState>();
    var status = fleet?.status ?? 'active';
    var adminId = fleet?.manager?.id;
    final adminsById = <int, ManagedAdminData>{
      for (final admin in data.assignableAdmins) admin.id: admin,
    };
    if (fleet?.manager != null) {
      adminsById[fleet!.manager!.id] = fleet.manager!;
    }
    final admins = adminsById.values.toList();
    final saved = await _editor(
      title: context.tr(fleet == null ? 'new_fleet' : 'edit_fleet'),
      subtitle: context.tr('fleet_form_help'),
      icon: Icons.corporate_fare_rounded,
      formKey: key,
      fields: [
        _requiredField(name, context.tr('fleet_name'), Icons.business_outlined),
        _requiredField(code, context.tr('fleet_code'), Icons.tag_rounded),
        TextFormField(
          controller: description,
          minLines: 2,
          maxLines: 4,
          decoration: corporateInputDecoration(
            label: context.tr('description'),
            icon: Icons.notes_rounded,
          ),
        ),
        DropdownButtonFormField<int>(
          initialValue: adminId,
          isExpanded: true,
          decoration: corporateInputDecoration(
            label: context.tr('responsible_admin'),
            icon: Icons.admin_panel_settings_outlined,
            helper: admins.isEmpty
                ? context.tr('no_available_admin')
                : context.tr('responsible_admin_help'),
          ),
          hint: Text(context.tr('select_admin')),
          items: admins
              .map(
                (admin) => DropdownMenuItem(
                  value: admin.id,
                  child: Text('${admin.name} · ${admin.email}'),
                ),
              )
              .toList(),
          onChanged: admins.isEmpty ? null : (value) => adminId = value,
        ),
        DropdownButtonFormField<String>(
          initialValue: status,
          decoration: corporateInputDecoration(
            label: context.tr('status'),
            icon: Icons.toggle_on_outlined,
          ),
          items: ['active', 'inactive']
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(context.tr(value)),
                ),
              )
              .toList(),
          onChanged: (value) => status = value ?? status,
        ),
      ],
    );
    if (!saved) return;
    await _run(
      () => fleet == null
          ? widget.session.createFleet(
              name: name.text.trim(),
              code: code.text.trim(),
              status: status,
              description: _nullable(description.text),
              adminId: adminId,
            )
          : widget.session.updateFleet(
              id: fleet.id,
              name: name.text.trim(),
              code: code.text.trim(),
              description: _nullable(description.text),
              status: status,
              adminId: adminId,
            ),
    );
  }

  Future<void> _createVehicle() => _saveVehicle();

  Future<void> _editVehicle(VehicleData vehicle) => _saveVehicle(vehicle);

  Future<void> _saveVehicle([VehicleData? vehicle]) async {
    final data = _data!;
    if (data.fleets.isEmpty) return;
    final name = TextEditingController(text: vehicle?.name);
    final registration = TextEditingController(text: vehicle?.registration);
    final brand = TextEditingController(text: vehicle?.brand);
    final model = TextEditingController(text: vehicle?.model);
    final color = TextEditingController(text: vehicle?.color);
    final year = TextEditingController(text: vehicle?.year?.toString());
    final speedLimit = TextEditingController(
      text: vehicle?.speedLimitKmh?.toString(),
    );
    final key = GlobalKey<FormState>();
    var fleetId = vehicle?.fleet?.id ?? data.fleets.first.id;
    var type =
        vehicle?.vehicleType ??
        data.vehicleTypes.firstOrNull ??
        'passenger_car';
    var status = vehicle?.status ?? 'active';
    final saved = await _editor(
      title: context.tr(vehicle == null ? 'new_vehicle' : 'edit_vehicle'),
      subtitle: context.tr('vehicle_form_help'),
      icon: Icons.directions_car_filled_outlined,
      formKey: key,
      fields: [
        DropdownButtonFormField<int>(
          initialValue: fleetId,
          decoration: corporateInputDecoration(
            label: context.tr('fleet'),
            icon: Icons.corporate_fare_outlined,
          ),
          items: data.fleets
              .map(
                (fleet) =>
                    DropdownMenuItem(value: fleet.id, child: Text(fleet.name)),
              )
              .toList(),
          onChanged: (value) => fleetId = value ?? fleetId,
        ),
        _requiredField(
          name,
          context.tr('vehicle_name'),
          Icons.directions_car_outlined,
        ),
        _requiredField(
          registration,
          context.tr('registration'),
          Icons.pin_outlined,
        ),
        DropdownButtonFormField<String>(
          initialValue: type,
          isExpanded: true,
          decoration: corporateInputDecoration(
            label: context.tr('vehicle_type'),
            icon: Icons.category_outlined,
          ),
          items: data.vehicleTypes
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(_humanize(value)),
                ),
              )
              .toList(),
          onChanged: (value) => type = value ?? type,
        ),
        TextFormField(
          controller: brand,
          decoration: corporateInputDecoration(
            label: context.tr('brand'),
            icon: Icons.factory_outlined,
          ),
        ),
        TextFormField(
          controller: model,
          decoration: corporateInputDecoration(
            label: context.tr('model'),
            icon: Icons.directions_car_filled_outlined,
          ),
        ),
        TextFormField(
          controller: color,
          decoration: corporateInputDecoration(
            label: context.tr('color'),
            icon: Icons.palette_outlined,
          ),
        ),
        TextFormField(
          controller: year,
          keyboardType: TextInputType.number,
          decoration: corporateInputDecoration(
            label: context.tr('year'),
            icon: Icons.calendar_today_outlined,
          ),
        ),
        TextFormField(
          controller: speedLimit,
          keyboardType: TextInputType.number,
          decoration: corporateInputDecoration(
            label: context.tr('maximum_speed'),
            icon: Icons.speed_outlined,
            helper: context.tr('maximum_speed_help'),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: status,
          decoration: corporateInputDecoration(
            label: context.tr('status'),
            icon: Icons.toggle_on_outlined,
          ),
          items: ['active', 'inactive', 'maintenance']
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(context.tr(value)),
                ),
              )
              .toList(),
          onChanged: (value) => status = value ?? status,
        ),
      ],
    );
    if (!saved) return;
    await _run(
      () => vehicle == null
          ? widget.session.createVehicle(
              fleetId: fleetId,
              name: name.text.trim(),
              registration: registration.text.trim(),
              vehicleType: type,
              status: status,
              brand: _nullable(brand.text),
              model: _nullable(model.text),
              color: _nullable(color.text),
              year: int.tryParse(year.text.trim()),
              speedLimitKmh: int.tryParse(speedLimit.text.trim()),
            )
          : widget.session.updateVehicle(
              id: vehicle.id,
              fleetId: fleetId,
              name: name.text.trim(),
              registration: registration.text.trim(),
              vehicleType: type,
              status: status,
              brand: _nullable(brand.text),
              model: _nullable(model.text),
              color: _nullable(color.text),
              year: int.tryParse(year.text.trim()),
              speedLimitKmh: int.tryParse(speedLimit.text.trim()),
            ),
    );
  }

  Future<void> _createTracker() => _saveTracker();

  Future<void> _editTracker(ManagedTrackerData tracker) =>
      _saveTracker(tracker);

  Future<void> _saveTracker([ManagedTrackerData? tracker]) async {
    final data = _data!;
    final vehicles = data.vehicles
        .where(
          (vehicle) =>
              !vehicle.trackingConfigured || vehicle.id == tracker?.vehicle?.id,
        )
        .toList();
    if (vehicles.isEmpty) {
      _showMessage(context.tr('no_unassigned_vehicle'));
      return;
    }
    final name = TextEditingController(text: tracker?.name);
    final imei = TextEditingController(text: tracker?.imei);
    final sim = TextEditingController(text: tracker?.simNumber);
    final operatorName = TextEditingController(text: tracker?.operatorName);
    final key = GlobalKey<FormState>();
    var vehicleId = tracker?.vehicle?.id ?? vehicles.first.id;
    var brand = data.trackerModels.containsKey(tracker?.brand)
        ? tracker!.brand
        : data.trackerModels.keys.first;
    var model = data.trackerModels[brand]!.contains(tracker?.model)
        ? tracker!.model
        : data.trackerModels[brand]!.first;
    var protocol = tracker?.protocol ?? data.protocols.firstOrNull ?? 'TCP';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => CorporateFormDialog(
          title: context.tr(tracker == null ? 'new_tracker' : 'edit_tracker'),
          subtitle: context.tr('tracker_form_help'),
          icon: Icons.sensors_rounded,
          formKey: key,
          cancelLabel: context.tr('cancel'),
          confirmLabel: context.tr('save'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _spaced([
              DropdownButtonFormField<int>(
                initialValue: vehicleId,
                isExpanded: true,
                decoration: corporateInputDecoration(
                  label: context.tr('assign_vehicle'),
                  icon: Icons.directions_car_outlined,
                ),
                items: vehicles
                    .map(
                      (vehicle) => DropdownMenuItem(
                        value: vehicle.id,
                        child: Text(
                          '${vehicle.name} · ${vehicle.registration}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => vehicleId = value ?? vehicleId,
              ),
              _requiredField(
                imei,
                context.tr('imei'),
                Icons.numbers_rounded,
                numeric: true,
              ),
              TextFormField(
                controller: name,
                decoration: corporateInputDecoration(
                  label: context.tr('tracker_name'),
                  icon: Icons.sensors_outlined,
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: brand,
                decoration: corporateInputDecoration(
                  label: context.tr('tracker_brand'),
                  icon: Icons.memory_outlined,
                ),
                items: data.trackerModels.keys
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_humanize(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    brand = value;
                    model = data.trackerModels[value]!.first;
                  });
                },
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(brand),
                initialValue: model,
                isExpanded: true,
                decoration: corporateInputDecoration(
                  label: context.tr('model'),
                  icon: Icons.developer_board_outlined,
                ),
                items: data.trackerModels[brand]!
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => model = value ?? model,
              ),
              TextFormField(
                controller: sim,
                keyboardType: TextInputType.phone,
                decoration: corporateInputDecoration(
                  label: context.tr('sim_number'),
                  icon: Icons.sim_card_outlined,
                ),
              ),
              TextFormField(
                controller: operatorName,
                decoration: corporateInputDecoration(
                  label: context.tr('operator'),
                  icon: Icons.cell_tower_outlined,
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: protocol,
                decoration: corporateInputDecoration(
                  label: context.tr('protocol'),
                  icon: Icons.settings_ethernet_rounded,
                ),
                items: data.protocols
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => protocol = value ?? protocol,
              ),
            ]),
          ),
        ),
      ),
    );
    if (saved != true) return;
    await _run(
      () => tracker == null
          ? widget.session.createTracker(
              vehicleId: vehicleId,
              imei: imei.text.trim(),
              brand: brand,
              model: model,
              protocol: protocol,
              name: _nullable(name.text),
              simNumber: _nullable(sim.text),
              operatorName: _nullable(operatorName.text),
            )
          : widget.session.updateTracker(
              id: tracker.id,
              vehicleId: vehicleId,
              imei: imei.text.trim(),
              brand: brand,
              model: model,
              protocol: protocol,
              name: _nullable(name.text),
              simNumber: _nullable(sim.text),
              operatorName: _nullable(operatorName.text),
            ),
    );
  }

  Future<void> _deleteFleet(ManagedFleetData fleet) async {
    final confirmed = await _confirmDelete(
      title: context.tr('delete_fleet'),
      message: context
          .tr('delete_fleet_confirmation')
          .replaceAll(':name', fleet.name),
      warning: context.tr('delete_fleet_cascade_warning'),
    );
    if (confirmed) await _run(() => widget.session.deleteFleet(fleet.id));
  }

  Future<void> _deleteVehicle(VehicleData vehicle) async {
    final confirmed = await _confirmDelete(
      title: context.tr('delete_vehicle'),
      message: context
          .tr('delete_vehicle_confirmation')
          .replaceAll(':name', vehicle.name),
    );
    if (confirmed) await _run(() => widget.session.deleteVehicle(vehicle.id));
  }

  Future<void> _deleteTracker(ManagedTrackerData tracker) async {
    final label = tracker.name?.trim().isNotEmpty == true
        ? tracker.name!
        : tracker.imei;
    final confirmed = await _confirmDelete(
      title: context.tr('delete_tracker'),
      message: context
          .tr('delete_tracker_confirmation')
          .replaceAll(':name', label),
    );
    if (confirmed) await _run(() => widget.session.deleteTracker(tracker.id));
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
    String? warning,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.danger,
              size: 34,
            ),
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                if (warning != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.danger.withValues(alpha: .24),
                      ),
                    ),
                    child: Text(
                      warning,
                      style: const TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.tr('cancel')),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.delete_outline),
                label: Text(context.tr('delete')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _editor({
    required String title,
    required String subtitle,
    required IconData icon,
    required GlobalKey<FormState> formKey,
    required List<Widget> fields,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => CorporateFormDialog(
            title: title,
            subtitle: subtitle,
            icon: icon,
            formKey: formKey,
            cancelLabel: context.tr('cancel'),
            confirmLabel: context.tr('save'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _spaced(fields),
            ),
          ),
        ) ??
        false;
  }

  TextFormField _requiredField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool numeric = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: numeric ? TextInputType.number : TextInputType.text,
    decoration: corporateInputDecoration(label: label, icon: icon),
    validator: (value) =>
        value == null || value.trim().isEmpty ? context.tr('required') : null,
  );

  List<Widget> _spaced(List<Widget> fields) => [
    for (var index = 0; index < fields.length; index++) ...[
      fields[index],
      if (index < fields.length - 1) const SizedBox(height: 12),
    ],
  ];

  Future<void> _run(Future<String> Function() operation) async {
    setState(() => _working = true);
    final fallbackMessage = context.tr('operation_successful');
    try {
      final message = await operation();
      _showMessage(message.isEmpty ? fallbackMessage : message);
      await Future.wait([
        _load(),
        widget.session.refreshWorkspace(silent: true),
      ]);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _nullable(String value) => value.trim().isEmpty ? null : value.trim();

  String _humanize(String value) => value
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

class _ManagementCard extends StatelessWidget {
  const _ManagementCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.color,
    required this.onEdit,
    required this.onDelete,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: SectionPanel(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusPill(label: status, color: statusColor),
            PopupMenuButton<_ManagementAction>(
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              onSelected: (action) => switch (action) {
                _ManagementAction.edit => onEdit(),
                _ManagementAction.delete => onDelete(),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _ManagementAction.edit,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.edit_outlined),
                    title: Text(context.tr('edit')),
                  ),
                ),
                PopupMenuItem(
                  value: _ManagementAction.delete,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
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
}

enum _ManagementAction { edit, delete }
