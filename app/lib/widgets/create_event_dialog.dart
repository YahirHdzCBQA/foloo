import 'package:flutter/material.dart';

import '../models/app_event.dart';
import '../models/app_plan.dart';
import '../models/pro_demo_data.dart';
import '../theme/foloo_theme.dart';

Future<AppEvent?> showCreateEventDialog(
  BuildContext context, {
  AppPlan plan = AppPlan.basic,
  List<ContentFile> contentFiles = const [],
}) async {
  return showDialog<AppEvent>(
    context: context,
    builder: (_) => _CreateEventDialog(plan: plan, contentFiles: contentFiles),
  );
}

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog({required this.plan, required this.contentFiles});
  final AppPlan plan;
  final List<ContentFile> contentFiles;

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _name = TextEditingController();
  final Set<String> _selectedFiles = {};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Crear evento'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Queda activo y los leads que captures se guardan ahí.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        const Text(
          'Nombre del evento',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        TextField(
          key: const Key('newEventNameField'),
          controller: _name,
          autofocus: true,
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(
              child: _DemoDate(label: 'Inicia', value: '12 ago 2026'),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _DemoDate(label: 'Termina', value: '14 ago 2026'),
            ),
          ],
        ),
        if (widget.plan.isPro && widget.contentFiles.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Contenido para este evento · ${_selectedFiles.length} de ${widget.contentFiles.length}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Puedes asignarlo ahora o más tarde. Sin contenido el correo demo sale igual, solo sin adjuntos.',
            style: TextStyle(fontSize: 11),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.maxFinite,
            height: 150,
            child: ListView(
              children: widget.contentFiles
                  .map(
                    (file) => CheckboxListTile(
                      dense: true,
                      value: _selectedFiles.contains(file.id),
                      title: Text(file.displayName),
                      onChanged: (selected) => setState(() {
                        if (selected ?? false) {
                          _selectedFiles.add(file.id);
                        } else {
                          _selectedFiles.remove(file.id);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('confirmCreateEventButton'),
        onPressed: () {
          final value = _name.text.trim();
          if (value.isEmpty) return;
          Navigator.pop(
            context,
            AppEvent(
              id: 'demo-${DateTime.now().microsecondsSinceEpoch}',
              name: value,
              startsOn: DateTime(2026, 8, 12),
              endsOn: DateTime(2026, 8, 14),
              active: true,
              contentFileIds: {..._selectedFiles},
            ),
          );
        },
        child: const Text('Crear'),
      ),
    ],
  );
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
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: FolooPalette.of(context).paper,
          borderRadius: BorderRadius.circular(FolooRadii.md),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 15),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
