import 'package:flutter/material.dart';

import '../models/app_destination.dart';
import '../models/app_event.dart';
import '../models/app_plan.dart';
import '../models/pro_demo_data.dart';
import '../theme/foloo_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_screen_header.dart';
import '../widgets/content_assignment_sheet.dart';

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
          AppScreenHeader(
            title: 'Contenido',
            subtitle: '${widget.files.length} ARCHIVOS · 4.9 MB',
            badge: 'PRO',
            onMenuPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: DropdownButtonFormField<String?>(
              key: const Key('contentEventFilter'),
              initialValue: _eventId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Filtrar por evento',
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todos los eventos (${widget.files.length})'),
                ),
                ...widget.events.map(
                  (event) => DropdownMenuItem<String?>(
                    value: event.id,
                    child: Text(
                      '${event.name} (${widget.files.where((f) => f.appliesTo(event)).length})',
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _eventId = value),
            ),
          ),
          Expanded(
            child: ListView.separated(
              key: const Key('contentLibraryList'),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              itemCount: _visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (_, index) {
                final file = _visible[index];
                final names = file.allEvents
                    ? 'Todos los eventos'
                    : widget.events
                          .where((e) => file.eventIds.contains(e.id))
                          .map((e) => e.name)
                          .join(' · ');
                return Material(
                  color: palette.paper,
                  borderRadius: BorderRadius.circular(FolooRadii.md),
                  child: ListTile(
                    key: Key('contentFile-${file.id}'),
                    minTileHeight: 76,
                    onTap: () => _edit(file),
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: Text(
                      file.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${file.fileName} · ${file.sizeLabel}\n$names',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Eliminar archivo',
                      onPressed: () => showDialog<void>(
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
                      icon: const Icon(Icons.delete_outline),
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
        child: Padding(
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
