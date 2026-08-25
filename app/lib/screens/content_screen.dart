import 'package:flutter/material.dart';

import '../models/app_destination.dart';
import '../models/app_event.dart';
import '../models/app_plan.dart';
import '../models/pro_demo_data.dart';
import '../theme/foloo_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/content_assignment_sheet.dart';
import '../widgets/module_header.dart';

class ContentScreen extends StatefulWidget {
  const ContentScreen({
    required this.files,
    required this.events,
    required this.recordsCount,
    required this.profile,
    required this.darkMode,
    required this.onDestinationSelected,
    required this.onAppearanceChanged,
    required this.onLogout,
    required this.onFileAdded,
    required this.onFileUpdated,
    required this.onFileDeleted,
    super.key,
  });
  final List<ContentFile> files;
  final List<AppEvent> events;
  final int recordsCount;
  final DemoProfile profile;
  final bool darkMode;
  final ValueChanged<AppDestination> onDestinationSelected;
  final ValueChanged<bool> onAppearanceChanged;
  final VoidCallback onLogout;
  final ValueChanged<ContentFile> onFileAdded;
  final ValueChanged<ContentFile> onFileUpdated;
  final ValueChanged<ContentFile> onFileDeleted;

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _eventId;

  List<ContentFile> get _visible => _eventId == null
      ? widget.files
      : widget.files.where((file) {
          final event = widget.events.firstWhere((item) => item.id == _eventId);
          return file.appliesTo(event);
        }).toList();

  Future<void> _add() async {
    // The native picker/server upload is intentionally replaced by a local PDF fixture.
    final result = await showContentAssignmentSheet(
      context,
      events: widget.events,
    );
    if (result != null) widget.onFileAdded(result);
  }

  Future<void> _edit(ContentFile file) async {
    final result = await showContentAssignmentSheet(
      context,
      events: widget.events,
      file: file,
    );
    if (result != null) widget.onFileUpdated(result);
  }

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: palette.card,
      endDrawer: AppDrawer(
        plan: AppPlan.pro,
        contentCount: widget.files.length,
        profile: widget.profile,
        activeDestination: AppDestination.content,
        recordsCount: widget.recordsCount,
        darkMode: widget.darkMode,
        onDestinationSelected: widget.onDestinationSelected,
        onAppearanceChanged: widget.onAppearanceChanged,
        onLogout: widget.onLogout,
      ),
      body: Column(
        children: [
          ModuleHeader(
            title: 'Contenido',
            subtitle: '${widget.files.length} archivos · 4.9 MB',
            onBack: () => widget.onDestinationSelected(AppDestination.home),
          ),
          Divider(height: 1, color: palette.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: SizedBox(
              height: 48,
              child: DropdownButtonFormField<String?>(
                key: const Key('contentEventFilter'),
                initialValue: _eventId,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today_outlined, size: 17),
                  border: FolooBorders.borderlessField,
                  enabledBorder: FolooBorders.borderlessField,
                  focusedBorder: FolooBorders.borderlessField,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'Todos los eventos · ${widget.files.length} archivos',
                    ),
                  ),
                  ...widget.events.map(
                    (event) => DropdownMenuItem<String?>(
                      value: event.id,
                      child: Text(
                        '${event.name} · ${widget.files.where((f) => f.appliesTo(event)).length} archivos',
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _eventId = value),
              ),
            ),
          ),
          Divider(height: 1, color: palette.line),
          Expanded(
            child: ListView.separated(
              key: const Key('contentLibraryList'),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              itemCount: _visible.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (_, index) {
                if (index == _visible.length) {
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: palette.paper,
                      borderRadius: BorderRadius.circular(FolooRadii.md),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 17,
                          color: palette.inkSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Los archivos viven en tu teléfono y se adjuntan al correo cuando hay señal.',
                            style: TextStyle(
                              color: palette.inkSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final file = _visible[index];
                final names = file.allEvents
                    ? const ['Todos los eventos']
                    : widget.events
                          .where((e) => file.eventIds.contains(e.id))
                          .map((e) => e.name)
                          .toList();
                return _ContentFileCard(
                  key: Key('contentFile-${file.id}'),
                  file: file,
                  eventNames: names,
                  onTap: () => _edit(file),
                  onDelete: () => showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Eliminar archivo'),
                      content: Text(
                        '¿Eliminar ${file.displayName} de la biblioteca local?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            widget.onFileDeleted(file);
                          },
                          child: const Text('Eliminar'),
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
          decoration: BoxDecoration(
            color: palette.card,
            border: Border(top: BorderSide(color: palette.line)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: FilledButton.icon(
            key: const Key('uploadPdfButton'),
            onPressed: _add,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Subir PDF'),
          ),
        ),
      ),
    );
  }
}

class _ContentFileCard extends StatelessWidget {
  const _ContentFileCard({
    required this.file,
    required this.eventNames,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final ContentFile file;
  final List<String> eventNames;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return Material(
      color: palette.paper,
      borderRadius: BorderRadius.circular(FolooRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FolooRadii.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 7, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(FolooRadii.sm),
                ),
                child: const Icon(Icons.description_outlined, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.displayName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${file.fileName} · ${file.sizeLabel}',
                      style: TextStyle(
                        color: palette.inkSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                    if (eventNames.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: eventNames
                            .map(
                              (name) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.card,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  name.replaceFirst(' México', ''),
                                  style: const TextStyle(fontSize: 9.5),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Eliminar archivo',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
