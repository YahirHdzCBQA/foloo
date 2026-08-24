import 'package:flutter/material.dart';

import '../models/app_event.dart';
import '../models/pro_demo_data.dart';
import '../theme/foloo_theme.dart';

Future<ContentFile?> showContentAssignmentSheet(
  BuildContext context, {
  required List<AppEvent> events,
  ContentFile? file,
}) => showModalBottomSheet<ContentFile>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _ContentAssignmentSheet(events: events, file: file),
);

class _ContentAssignmentSheet extends StatefulWidget {
  const _ContentAssignmentSheet({required this.events, this.file});
  final List<AppEvent> events;
  final ContentFile? file;

  @override
  State<_ContentAssignmentSheet> createState() =>
      _ContentAssignmentSheetState();
}

class _ContentAssignmentSheetState extends State<_ContentAssignmentSheet> {
  final _name = TextEditingController();
  final _search = TextEditingController();
  late Set<String> _selected;
  late Set<String> _selectionBeforeAll;
  late bool _all;

  @override
  void initState() {
    super.initState();
    _name.text = widget.file?.displayName ?? '';
    _selected = {...?widget.file?.eventIds};
    _selectionBeforeAll = {..._selected};
    _all = widget.file?.allEvents ?? false;
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  void _toggleAll(bool value) {
    setState(() {
      if (value) _selectionBeforeAll = {..._selected};
      _all = value;
      if (!value) _selected = {..._selectionBeforeAll};
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = widget.events
        .where((event) => event.name.toLowerCase().contains(query))
        .toList();
    final editing = widget.file != null;
    return FractionallySizedBox(
      heightFactor: .9,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            editing ? 'Editar eventos del archivo' : 'Subir contenido',
          ),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!editing) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FolooPalette.of(context).paper,
                    borderRadius: BorderRadius.circular(FolooRadii.md),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('documento-demo.pdf · PDF · 1.2 MB'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('contentDisplayNameField'),
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nombre para mostrar',
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                '¿En qué eventos aplica? · ${_all ? widget.events.length : _selected.length} de ${widget.events.length}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('contentEventSearch'),
                controller: _search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar evento',
                ),
              ),
              SwitchListTile(
                key: const Key('allEventsSwitch'),
                contentPadding: EdgeInsets.zero,
                value: _all,
                onChanged: _toggleAll,
                title: const Text('Todos los eventos'),
                subtitle: Text(
                  _all
                      ? 'Ignora la selección de abajo.'
                      : 'La selección individual se conserva.',
                ),
              ),
              Expanded(
                child: ListView.builder(
                  key: const Key('contentEventsList'),
                  itemCount: visible.length,
                  itemBuilder: (_, index) {
                    final event = visible[index];
                    return CheckboxListTile(
                      key: Key('contentEvent-${event.id}'),
                      enabled: !_all,
                      value: _selected.contains(event.id),
                      title: Text(event.name),
                      subtitle: event.active
                          ? const Text('Evento activo')
                          : null,
                      onChanged: (value) => setState(() {
                        if (value ?? false) {
                          _selected.add(event.id);
                        } else {
                          _selected.remove(event.id);
                        }
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            child: FilledButton(
              key: const Key('confirmContentButton'),
              onPressed: () {
                final displayName = editing
                    ? widget.file!.displayName
                    : _name.text.trim();
                if (displayName.isEmpty) return;
                // TODO(BACKEND): Upload PDFs and persist event assignments.
                Navigator.pop(
                  context,
                  (widget.file ??
                          ContentFile(
                            id: 'demo-${DateTime.now().microsecondsSinceEpoch}',
                            displayName: displayName,
                            fileName: 'documento-demo.pdf',
                            sizeLabel: '1.2 MB',
                          ))
                      .copyWith(
                        displayName: displayName,
                        allEvents: _all,
                        eventIds: {..._selected},
                      ),
                );
              },
              child: Text(editing ? 'Guardar cambios' : 'Subir'),
            ),
          ),
        ),
      ),
    );
  }
}
