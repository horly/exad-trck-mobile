import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/app_models.dart';

typedef HistoryLoader =
    Future<VehicleTripsData> Function(String period, String? from, String? to);

/// Compact history stays on the map, including when its body is collapsed.
class TripHistoryPanel extends StatefulWidget {
  const TripHistoryPanel({
    super.key,
    required this.vehicleName,
    required this.load,
    required this.onSelection,
    required this.onPlayback,
    required this.onClose,
    this.active = true,
    this.onCollapsedChanged,
  });
  final String vehicleName;
  final HistoryLoader load;
  final void Function(List<VehicleTripData>, VehicleHistoryItem?) onSelection;
  final void Function(VehicleTripData, double) onPlayback;
  final VoidCallback onClose;
  final bool active;
  final ValueChanged<bool>? onCollapsedChanged;

  @override
  State<TripHistoryPanel> createState() => _TripHistoryPanelState();
}

class _TripHistoryPanelState extends State<TripHistoryPanel> {
  String period = 'today';
  DateTimeRange? range;
  VehicleTripsData? data;
  Object? error;
  bool loading = true, detailed = false, collapsed = false;
  Set<String> selected = {};
  String? selectedParking;
  int request = 0, speed = 1;
  Timer? playback;
  double progress = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant TripHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && playback != null) {
      playback?.cancel();
      playback = null;
    }
  }

  @override
  void dispose() {
    request++;
    playback?.cancel();
    super.dispose();
  }

  String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _duration(int s) {
    final n = s < 0 ? 0 : s;
    return '${n >= 3600 ? '${n ~/ 3600} h ' : ''}${(n ~/ 60) % 60} min ${n % 60} s';
  }

  List<VehicleTripData> get visible =>
      data?.trips.where((t) => selected.contains(t.id)).toList() ?? [];
  VehicleTripData? get replayTrip =>
      visible.length == 1 && selectedParking == null ? visible.first : null;

  Future<void> _load() async {
    final id = ++request;
    playback?.cancel();
    playback = null;
    progress = 0;
    setState(() {
      loading = true;
      error = null;
      data = null;
      selected = {};
      selectedParking = null;
    });
    // Avoid calling the parent's setState while this panel is being mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && id == request) widget.onSelection([], null);
    });
    try {
      final result = await widget.load(
        period,
        range == null ? null : _date(range!.start),
        range == null ? null : _date(range!.end),
      );
      if (!mounted || id != request) return;
      setState(() {
        data = result;
        loading = false;
        detailed = false;
        selected = result.trips.map((t) => t.id).toSet();
      });
      widget.onSelection(visible, null);
    } catch (e) {
      if (mounted && id == request) {
        setState(() {
          loading = false;
          error = e;
        });
      }
    }
  }

  void _select(Set<String> ids, {VehicleHistoryItem? parking}) {
    playback?.cancel();
    playback = null;
    setState(() {
      selected = ids;
      selectedParking = parking?.id;
      progress = 0;
    });
    widget.onSelection(visible, parking);
  }

  void _play() {
    final trip = replayTrip;
    if (trip == null) return;
    if (playback != null) {
      setState(() {
        playback!.cancel();
        playback = null;
      });
      return;
    }
    if (progress >= 1) progress = 0;
    setState(() {
      playback = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || !widget.active) {
          playback?.cancel();
          playback = null;
          return;
        }
        setState(() {
          progress =
              (progress +
                      .2 *
                          speed /
                          (trip.durationSeconds > 0 ? trip.durationSeconds : 1))
                  .clamp(0, 1);
          if (progress >= 1) {
            playback?.cancel();
            playback = null;
          }
        });
        widget.onPlayback(trip, progress);
      });
    });
  }

  Future<void> _period(String value) async {
    if (value == 'custom') {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year, now.month, now.day),
        initialDateRange: range,
      );
      if (!mounted || picked == null) return;
      range = picked;
    } else {
      range = null;
    }
    period = value;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme, l = context.tr;
    final trips = data?.trips ?? [];
    return Material(
      elevation: 8,
      shadowColor: scheme.primary.withValues(alpha: .22),
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(color: scheme.primary),
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: IconTheme(
              data: IconThemeData(color: scheme.onPrimary),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.onPrimary.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.history, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l('history_title'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.vehicleName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: .82),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l('history_collapse'),
                    onPressed: () {
                      setState(() => collapsed = !collapsed);
                      widget.onCollapsedChanged?.call(collapsed);
                    },
                    icon: Icon(
                      collapsed ? Icons.expand_more : Icons.expand_less,
                    ),
                  ),
                  IconButton(
                    tooltip: l('close'),
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              padding: const EdgeInsets.only(left: 12),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .05),
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range_outlined,
                    color: scheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: period,
                        isExpanded: true,
                        isDense: true,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        dropdownColor: scheme.surface,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        items:
                            {
                                  'today': l('today'),
                                  'yesterday': l('yesterday'),
                                  'week': l('this_week'),
                                  'current_month': l('this_month'),
                                  'last_month': l('history_last_month'),
                                  'custom': range == null
                                      ? l('history_custom')
                                      : '${_date(range!.start)} – ${_date(range!.end)}',
                                }.entries
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(
                                      e.value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v != null) unawaited(_period(v));
                        },
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l('history_refresh'),
                    icon: Icon(Icons.refresh, size: 20, color: scheme.primary),
                    onPressed: () => unawaited(_load()),
                  ),
                ],
              ),
            ),
            if (!loading && error == null && data != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    _tool(
                      l('history_play'),
                      playback == null
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      replayTrip == null ? null : _play,
                      primary: true,
                    ),
                    const SizedBox(width: 6),
                    _tool(
                      l('history_reset'),
                      Icons.replay,
                      replayTrip == null
                          ? null
                          : () {
                              playback?.cancel();
                              setState(() {
                                playback = null;
                                progress = 0;
                              });
                              widget.onPlayback(replayTrip!, 0);
                            },
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 48,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(44, 40),
                        ),
                        onPressed: () => setState(
                          () => speed = switch (speed) {
                            1 => 10,
                            10 => 30,
                            30 => 60,
                            _ => 1,
                          },
                        ),
                        child: Text('×$speed'),
                      ),
                    ),
                    _tool(
                      l('history_overview'),
                      Icons.format_list_bulleted,
                      () {
                        setState(() => detailed = false);
                        _select(trips.map((t) => t.id).toSet());
                      },
                    ),
                    const Spacer(),
                    Tooltip(
                      message: l('history_select_all'),
                      child: Checkbox(
                        tristate: true,
                        value: selected.isEmpty
                            ? false
                            : selected.length == trips.length
                            ? true
                            : null,
                        onChanged: trips.isEmpty
                            ? null
                            : (_) => _select(
                                selected.length == trips.length
                                    ? {}
                                    : trips.map((t) => t.id).toSet(),
                              ),
                        semanticLabel: l('history_select_all'),
                      ),
                    ),
                  ],
                ),
              ),
              if (replayTrip != null)
                SizedBox(
                  height: 26,
                  child: Slider(
                    value: progress,
                    onChanged: (v) {
                      playback?.cancel();
                      setState(() {
                        playback = null;
                        progress = v;
                      });
                      widget.onPlayback(replayTrip!, v);
                    },
                    label: _duration(
                      (progress * replayTrip!.durationSeconds).round(),
                    ),
                  ),
                ),
            ],
            Divider(height: 1, color: scheme.outlineVariant),
            Flexible(
              child: loading
                  ? const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : error != null
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l('history_failed')),
                          TextButton(
                            onPressed: () => unawaited(_load()),
                            child: Text(l('history_retry')),
                          ),
                        ],
                      ),
                    )
                  : _content(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tool(
    String title,
    IconData icon,
    VoidCallback? action, {
    bool primary = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        tooltip: title,
        onPressed: action,
        style: IconButton.styleFrom(
          backgroundColor: primary
              ? scheme.primary
              : scheme.primary.withValues(alpha: .06),
          foregroundColor: primary ? scheme.onPrimary : scheme.primary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: .04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          padding: EdgeInsets.zero,
        ),
        icon: Icon(icon, size: 22),
      ),
    );
  }

  Widget _endpoint(String time, String date, String address) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                date,
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 5, 9, 0),
          child: Icon(Icons.circle_outlined, size: 11, color: scheme.primary),
        ),
        Expanded(
          child: Text(
            address,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context) {
    final d = data!, scheme = Theme.of(context).colorScheme;
    if (d.trips.isEmpty && d.history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(context.tr('no_trip')),
      );
    }
    if (!detailed) {
      final first = d.history.firstOrNull,
          last = d.history.lastOrNull,
          firstTrip = d.trips.firstOrNull,
          lastTrip = d.trips.lastOrNull;
      return SingleChildScrollView(
        child: InkWell(
          key: const Key('history-overview'),
          onTap: () => setState(() => detailed = true),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('history_overview'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                _endpoint(
                  first?.startTime ?? firstTrip?.startTime ?? '',
                  first?.date ?? firstTrip?.date ?? '',
                  first?.address ?? firstTrip?.startAddress ?? '',
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _metric(
                        Icons.route,
                        '${d.distanceKm.toStringAsFixed(2)} km',
                      ),
                      _metric(
                        Icons.schedule,
                        _duration(
                          d.elapsedSeconds > 0
                              ? d.elapsedSeconds
                              : d.durationSeconds,
                        ),
                      ),
                    ],
                  ),
                ),
                _endpoint(
                  last?.endTime ?? lastTrip?.endTime ?? '',
                  last?.endDate ?? lastTrip?.endDate ?? '',
                  last?.type == 'trip'
                      ? lastTrip?.endAddress ?? ''
                      : last?.address ?? lastTrip?.endAddress ?? '',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${d.count} ${context.tr('trips')} · ${d.parkingCount} ${context.tr('history_parking')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    final items = d.history.isNotEmpty
        ? d.history
        : d.trips
              .map(
                (t) => VehicleHistoryItem(
                  id: t.id,
                  type: 'trip',
                  date: t.date,
                  endDate: t.endDate,
                  startTime: t.startTime,
                  endTime: t.endTime,
                  address: t.startAddress,
                  durationSeconds: t.durationSeconds,
                ),
              )
              .toList();
    return ListView.builder(
      key: const Key('history-details'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index],
            trip = d.trips.where((t) => t.id == item.id).firstOrNull;
        final color = trip?.color ?? scheme.primary,
            parking = item.type == 'parking',
            selectedRow = trip != null
                ? selected.contains(trip.id)
                : selectedParking == item.id;
        return Column(
          children: [
            if (index == 0 || items[index - 1].date != item.date)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: scheme.outlineVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        item.date,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: scheme.outlineVariant)),
                  ],
                ),
              ),
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: selectedRow
                    ? scheme.primary.withValues(alpha: .045)
                    : scheme.surface,
                border: Border.all(
                  color: selectedRow
                      ? scheme.primary.withValues(alpha: .35)
                      : scheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                key: Key('history-item-${item.id}'),
                onTap: trip != null
                    ? () => _select({trip.id})
                    : item.coordinate == null
                    ? null
                    : () => _select({}, parking: item),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: trip != null
                                ? Icon(Icons.route, size: 19, color: color)
                                : parking
                                ? Text(
                                    'P',
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : Icon(
                                    Icons.wifi_off,
                                    size: 18,
                                    color: scheme.onSurfaceVariant,
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              trip != null
                                  ? context.trFormat('trip_number', {
                                      'number': trip.index,
                                    })
                                  : parking
                                  ? context.tr('history_parking')
                                  : context.tr('history_gap'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          if (trip != null)
                            Checkbox(
                              value: selected.contains(trip.id),
                              onChanged: (checked) {
                                final ids = Set<String>.of(selected);
                                checked == true
                                    ? ids.add(trip.id)
                                    : ids.remove(trip.id);
                                _select(ids);
                              },
                            )
                          else
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: scheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (trip != null) ...[
                        _endpoint(trip.startTime, trip.date, trip.startAddress),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            children: [
                              _metric(
                                Icons.route,
                                '${trip.distanceKm.toStringAsFixed(2)} km',
                              ),
                              _metric(
                                Icons.schedule,
                                _duration(trip.durationSeconds),
                              ),
                            ],
                          ),
                        ),
                        _endpoint(trip.endTime, trip.endDate, trip.endAddress),
                      ] else ...[
                        if (item.address.isNotEmpty)
                          Text(
                            item.address,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          '${item.startTime} – ${item.endTime} · ${_duration(item.durationSeconds)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _metric(IconData icon, String text) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
