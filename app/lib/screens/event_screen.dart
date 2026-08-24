import 'package:flutter/material.dart';

import '../models/app_destination.dart';
import '../models/app_event.dart';
import '../theme/foloo_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/create_event_dialog.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({
    required this.events,
    required this.recordsCount,
    required this.darkMode,
    required this.onDestinationSelected,
    required this.onAppearanceChanged,
    required this.onLogout,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
    required this.onBack,
    this.profile = DemoBasicData.profile,
    super.key,
  });

  final List<AppEvent> events;
  final int recordsCount;
  final bool darkMode;
  final ValueChanged<AppDestination> onDestinationSelected;
  final ValueChanged<bool> onAppearanceChanged;
  final VoidCallback onLogout;
  final ValueChanged<AppEvent> onCreate;
  final ValueChanged<AppEvent> onUpdate;
  final ValueChanged<AppEvent> onDelete;
  final VoidCallback onBack;
  final DemoProfile profile;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _editingName = TextEditingController();
  AppEvent? _editing;

  @override
  void dispose() {
    _editingName.dispose();
    super.dispose();
  }

  void _startEditing(AppEvent event) {
    _editingName.text = event.name;
    setState(() => _editing = event);
  }

  Future<void> _createEvent() async {
    final created = await showCreateEventDialog(context);
    if (created == null) return;
    widget.onCreate(created);
  }

  @override
  Widget build(BuildContext context) {
    return _editing == null ? _buildList() : _buildEditor(_editing!);
  }

  Widget _drawer() => AppDrawer(
    profile: widget.profile,
    activeDestination: AppDestination.events,
    recordsCount: widget.recordsCount,
    darkMode: widget.darkMode,
    onDestinationSelected: widget.onDestinationSelected,
    onAppearanceChanged: widget.onAppearanceChanged,
    onLogout: widget.onLogout,
  );

  Widget _buildList() {
    final palette = FolooPalette.of(context);
    final total = widget.events.fold<int>(
      0,
      (sum, event) => sum + event.demoLeadCount,
    );
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _drawer(),
      body: Column(
        children: [
          _EventsHeader(
            subtitle: '${widget.events.length} eventos · $total leads en total',
            onBack: widget.onBack,
            onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          Divider(height: 1, color: palette.line),
          Expanded(
            child: widget.events.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 44),
                          const SizedBox(height: 14),
                          const Text(
                            'Aún no tienes eventos',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Crea el primero para comenzar a capturar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: palette.inkSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    key: const Key('eventsList'),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    itemCount: widget.events.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == widget.events.length) {
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: palette.paper,
                            borderRadius: BorderRadius.circular(FolooRadii.md),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: palette.inkSecondary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Al eliminar un evento sus leads dejan de aparecer en la app. La hoja de cálculo no se toca.',
                                  style: TextStyle(
                                    color: palette.inkSecondary,
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final event = widget.events[index];
                      return InkWell(
                        key: Key('event-${event.id}'),
                        onTap: () => _startEditing(event),
                        borderRadius: BorderRadius.circular(FolooRadii.md),
                        child: Container(
                          height: 80,
                          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                          decoration: BoxDecoration(
                            color: palette.paper,
                            borderRadius: BorderRadius.circular(FolooRadii.md),
                            border: event.active
                                ? Border.all(color: palette.ink, width: 2)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            event.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        if (event.active) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: palette.card,
                                              border: Border.all(
                                                color: palette.ink,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(99),
                                            ),
                                            child: const Text(
                                              'Activo',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_date(event.startsOn)} · ${event.demoLeadCount} leads${event.demoPendingCount > 0 ? ' · ${event.demoPendingCount} por subir' : ''}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.inkSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Eliminar evento',
                                onPressed: () => widget.onDelete(event),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 19,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: palette.card,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: FilledButton.icon(
            key: const Key('createEventButton'),
            onPressed: _createEvent,
            icon: const Icon(Icons.add),
            label: const Text('Crear evento'),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(AppEvent event) {
    final palette = FolooPalette.of(context);
    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              color: palette.card,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Row(
                children: [
                  IconButton.filled(
                    key: const Key('closeEventEditorButton'),
                    onPressed: () => setState(() => _editing = null),
                    style: IconButton.styleFrom(
                      backgroundColor: FolooColors.lime,
                      foregroundColor: FolooColors.ink,
                    ),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Editar evento',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          event.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.inkSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Nombre del evento',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 7),
                  TextField(
                    key: const Key('editEventNameField'),
                    controller: _editingName,
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Expanded(
                        child: _DemoDate(label: 'Inicia', value: '12 ago 2026'),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _DemoDate(
                          label: 'Termina',
                          value: '14 ago 2026',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Este evento',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          value: '${event.demoLeadCount}',
                          label: 'leads',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Metric(
                          value: '${event.demoPendingCount}',
                          label: 'por subir',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('deleteEventButton'),
                    onPressed: () {
                      widget.onDelete(event);
                      setState(() => _editing = null);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.ink,
                      foregroundColor: palette.card,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar evento'),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Sus leads dejan de aparecer en la app. La hoja de cálculo no se toca.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.inkSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: palette.card,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: FilledButton(
            key: const Key('saveEventButton'),
            onPressed: () {
              final value = _editingName.text.trim();
              if (value.isNotEmpty) {
                widget.onUpdate(event.copyWith(name: value));
              }
              setState(() => _editing = null);
            },
            child: const Text('Guardar cambios'),
          ),
        ),
      ),
    );
  }

  String _date(DateTime date) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _EventsHeader extends StatelessWidget {
  const _EventsHeader({
    required this.subtitle,
    required this.onBack,
    required this.onMenu,
  });

  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return Material(
      color: palette.card,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 13),
          child: Row(
            children: [
              IconButton.filled(
                key: const Key('eventsBackButton'),
                tooltip: 'Regresar',
                onPressed: onBack,
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: FolooColors.lime,
                  foregroundColor: FolooColors.ink,
                ),
                icon: const Icon(Icons.arrow_back, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mis eventos',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.inkSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('eventsMenuButton'),
                tooltip: 'Abrir menú',
                onPressed: onMenu,
                icon: const Icon(Icons.menu_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoDate extends StatelessWidget {
  const _DemoDate({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 7),
      Container(
        height: 56,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: FolooPalette.of(context).paper,
          borderRadius: BorderRadius.circular(FolooRadii.md),
        ),
        child: Text(value),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: FolooPalette.of(context).paper,
      borderRadius: BorderRadius.circular(FolooRadii.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
