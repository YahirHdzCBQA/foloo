import 'package:flutter/material.dart';

import '../models/app_event.dart';
import '../theme/foloo_theme.dart';

Future<AppEvent?> showCreateEventDialog(BuildContext context) async {
  return showDialog<AppEvent>(
    context: context,
    builder: (_) => const _CreateEventDialog(),
  );
}

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog();

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
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
