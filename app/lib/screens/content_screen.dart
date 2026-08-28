/// Pro-only content library for locally selected, event-scoped PDFs.
///
/// The screen owns native selection and session metadata only; upload,
/// persistence and delivery remain backend work.
library;

import 'package:flutter/material.dart';

import '../models/app_destination.dart';
import '../models/app_event.dart';
import '../models/app_plan.dart';
import '../models/pro_demo_data.dart';
import '../services/pdf_picker_service.dart';
import '../theme/foloo_theme.dart';
import '../l10n/l10n.dart';
import '../widgets/app_drawer.dart';
import '../widgets/content_assignment_sheet.dart';
import '../widgets/module_header.dart';

/// Lists and edits session-only Pro content metadata.
///
/// Basic accounts must never be routed to this surface (RNF-18).
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
    this.pdfPickerService,
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
  final PdfPickerService? pdfPickerService;

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final PdfPickerService _pdfPicker;
  String? _eventId;

  @override
  void initState() {
    super.initState();
    _pdfPicker = widget.pdfPickerService ?? const DevicePdfPickerService();
  }

  List<ContentFile> get _visible => _eventId == null
      ? widget.files
      : widget.files.where((file) {
          final event = widget.events.firstWhere((item) => item.id == _eventId);
          return file.appliesTo(event);
        }).toList();

  Future<void> _add() async {
    PickedPdf? pickedPdf;
    try {
      pickedPdf = await _pdfPicker.pickPdf();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.pdfSelectionError)));
      }
      return;
    }
    if (!mounted || pickedPdf == null) return;
    final result = await showContentAssignmentSheet(
      context,
      events: widget.events,
      pickedPdf: pickedPdf,
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
            title: context.l10n.contentTitle,
            subtitle: widget.files.isEmpty
                ? context.l10n.noFiles
                : context.l10n.filesSummary(widget.files.length),
            onBack: () => widget.onDestinationSelected(AppDestination.home),
          ),
          Divider(height: 1, color: palette.line),
          if (widget.files.isNotEmpty) ...[
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
                        context.l10n.allEventsFiles(
                          context.l10n.fileCount(widget.files.length),
                        ),
                      ),
                    ),
                    ...widget.events.map(
                      (event) => DropdownMenuItem<String?>(
                        value: event.id,
                        child: Text(
                          context.l10n.eventFiles(
                            event.name,
                            context.l10n.fileCount(
                              widget.files
                                  .where((f) => f.appliesTo(event))
                                  .length,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _eventId = value),
                ),
              ),
            ),
            Divider(height: 1, color: palette.line),
          ],
          Expanded(
            child: widget.files.isEmpty
                ? const _EmptyContentLibrary()
                : ListView.separated(
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
                                  context.l10n.localFilesHelp,
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
                          ? [context.l10n.allEvents]
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
                            title: Text(context.l10n.deleteFile),
                            content: Text(
                              context.l10n.deleteLocalFileQuestion(
                                file.displayName,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: Text(context.l10n.cancel),
                              ),
                              FilledButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  widget.onFileDeleted(file);
                                },
                                child: Text(context.l10n.delete),
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
            label: Text(context.l10n.uploadPdf),
          ),
        ),
      ),
    );
  }
}

class _EmptyContentLibrary extends StatelessWidget {
  const _EmptyContentLibrary();

  @override
  Widget build(BuildContext context) {
    final palette = FolooPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: palette.paper,
                borderRadius: BorderRadius.circular(FolooRadii.lg),
              ),
              child: const Icon(Icons.description_outlined, size: 28),
            ),
            const SizedBox(height: 18),
            Text(
              context.l10n.emptyContentTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.emptyContentHelp,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.inkSecondary,
                fontSize: 13,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 28),
            Container(
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
                      context.l10n.localFilesHelp,
                      style: TextStyle(
                        color: palette.inkSecondary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                tooltip: context.l10n.deleteFile,
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
