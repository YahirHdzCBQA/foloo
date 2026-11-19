import 'dart:convert';

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/models/app_event.dart';
import 'package:foloo/models/content_file.dart';
import 'package:foloo/models/lead_draft.dart';
import 'package:foloo/models/session_lead.dart';
import 'package:foloo/services/records_export_service.dart';

const labels = RecordsExportLabels(
  headers: [
    'Fecha/hora',
    'Nombre',
    'Apellido',
    'Puesto',
    'Empresa',
    'Correo',
    'Teléfono',
    'Tipo',
    'Interés',
    'Origen',
    'Evento',
    'Lugar',
    'Nota escrita',
    'Contenido compartido',
    'Archivo original',
  ],
  customer: 'Cliente',
  partner: 'Partner',
  supplier: 'Proveedor',
  low: 'Bajo',
  medium: 'Medio',
  high: 'Alto',
  event: 'Evento',
  direct: 'Lead directo',
);

SessionLead record(
  String eventId, {
  String name = 'José, "Pepe"',
  List<String> contentIds = const [],
  List<String> contentNames = const [],
}) => SessionLead(
  localId: 'technical-id',
  folio: 'hidden-folio',
  capturedAt: DateTime.now(),
  lead: LeadDraft(
    name: name,
    lastName: 'Álvarez',
    role: '',
    company: 'Niñez\nMéxico',
    email: 'jose@example.com',
    phone: '',
    type: LeadType.partner,
    interest: InterestLevel.medium,
    note: 'Unicode pingüino',
    originKind: LeadOriginKind.event,
    eventLocalId: eventId,
    eventName: 'Expo / México',
    audioSeconds: 10,
    audioLocalPath: '/private/voice.m4a',
    contentFileIds: contentIds,
    contentNames: contentNames,
  ),
);

SessionLead directRecord({required String name, DateTime? capturedAt}) =>
    SessionLead(
      localId: 'direct-$name',
      folio: 'hidden',
      capturedAt: capturedAt ?? DateTime(2026, 9, 15, 12),
      lead: LeadDraft(
        name: name,
        lastName: '',
        role: '',
        company: 'Foloo',
        email: 'direct@example.com',
        phone: '',
        type: LeadType.customer,
        interest: InterestLevel.high,
        note: '',
        originKind: LeadOriginKind.direct,
        audioSeconds: 0,
        place: 'León',
      ),
    );

void main() {
  const contentFiles = [
    ContentFile(
      id: 'catalog',
      displayName: 'Catálogo de productos',
      fileName: 'catálogo_productos.pdf',
      sizeLabel: '1 MB',
    ),
    ContentFile(
      id: 'presentation',
      displayName: 'Presentación comercial',
      fileName: 'presentacion,comercial.pdf',
      sizeLabel: '2 MB',
    ),
  ];
  final event = AppEvent(
    id: 'event-a',
    name: 'Expo / México',
    startsOn: DateTime(2026, 9, 1),
    endsOn: DateTime(2026, 9, 2),
  );

  test('REG-10–13 CSV is event-only, BOM UTF-8 and RFC 4180', () {
    final file = const RecordsExportService().build(
      event: event,
      records: [
        record(
          'event-a',
          contentIds: const ['catalog', 'presentation'],
          contentNames: const [
            'Catálogo de productos',
            'Presentación comercial',
          ],
        ),
        record('event-b', name: 'Excluded'),
      ],
      format: RecordsExportFormat.csv,
      labels: labels,
      contentFiles: contentFiles,
      generatedAt: DateTime(2026, 9, 15),
    );
    expect(file.filename, 'foloo_Expo _ México_2026-09-15.csv');
    expect(file.bytes.take(3), [0xEF, 0xBB, 0xBF]);
    final text = utf8.decode(file.bytes.skip(3).toList());
    expect(text, contains('"José, ""Pepe"""'));
    expect(text, contains('"Niñez\nMéxico"'));
    expect(text, isNot(contains('Excluded')));
    expect(text, isNot(contains('technical-id')));
    expect(text, isNot(contains('/private/voice.m4a')));
    expect(text.split('\r\n').first.split(','), hasLength(15));
    expect(text, contains('Catálogo de productos; Presentación comercial'));
    expect(
      text,
      contains('"catálogo_productos.pdf; presentacion,comercial.pdf"'),
    );
    expect(
      text,
      contains(RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}')),
    );
  });

  test('REG-09 XLSX is real, Unicode-safe and follows the 15-column order', () {
    final file = const RecordsExportService().build(
      event: event,
      records: [
        record(
          'event-a',
          contentIds: const ['catalog', 'presentation'],
          contentNames: const [
            'Catálogo de productos',
            'Presentación comercial',
          ],
        ),
      ],
      format: RecordsExportFormat.xlsx,
      labels: labels,
      contentFiles: contentFiles,
      generatedAt: DateTime(2026, 9, 15),
    );
    expect(file.bytes.take(2), [0x50, 0x4B]);
    final workbook = Excel.decodeBytes(file.bytes);
    final rows = workbook.tables['Records']!.rows;
    expect(rows.first.map((cell) => cell?.value.toString()), labels.headers);
    expect(rows[1], hasLength(15));
    expect(rows[1][1]?.value.toString(), 'José, "Pepe"');
    expect(rows[1][4]?.value.toString(), 'Niñez\nMéxico');
    expect(
      rows[1][13]?.value.toString(),
      'Catálogo de productos; Presentación comercial',
    );
    expect(
      rows[1][14]?.value.toString(),
      'catálogo_productos.pdf; presentacion,comercial.pdf',
    );
  });

  test('REG-11 legacy Content keeps its visible name and an empty file', () {
    final file = const RecordsExportService().build(
      event: event,
      records: [
        record(
          'event-a',
          contentIds: const ['deleted-content'],
          contentNames: const ['Contenido histórico'],
        ),
      ],
      format: RecordsExportFormat.xlsx,
      labels: labels,
      contentFiles: contentFiles,
      generatedAt: DateTime(2026, 9, 15),
    );
    final row = Excel.decodeBytes(file.bytes).tables['Records']!.rows[1];
    expect(row[13]?.value.toString(), 'Contenido histórico');
    expect(row[14]?.value?.toString() ?? '', isEmpty);
  });

  test('REG-09 direct XLSX/CSV include only direct leads', () {
    final service = const RecordsExportService();
    for (final format in RecordsExportFormat.values) {
      final file = service.buildDirect(
        scopeName: 'Leads directos',
        records: [
          directRecord(name: 'Directo'),
          record('event-a'),
        ],
        format: format,
        labels: labels,
        generatedAt: DateTime(2026, 9, 15),
      );
      expect(file.filename, 'foloo_Leads directos_2026-09-15.${format.name}');
      if (format == RecordsExportFormat.csv) {
        final text = utf8.decode(file.bytes.skip(3).toList());
        expect(text, contains('Directo'));
        expect(text, isNot(contains('José')));
        expect(text, contains(',Lead directo,,León,'));
      } else {
        final rows = Excel.decodeBytes(file.bytes).tables['Records']!.rows;
        expect(rows, hasLength(2));
        expect(rows[1][1]?.value.toString(), 'Directo');
        expect(rows[1][10]?.value.toString(), '');
      }
    }
  });

  test('REG-09 direct scope excludes event leads without date filtering', () {
    final records = const RecordsExportService().directRecords(
      records: [
        directRecord(name: 'Before', capturedAt: DateTime(2026, 9, 9, 23)),
        directRecord(name: 'Start', capturedAt: DateTime(2026, 9, 10, 0)),
        directRecord(name: 'End', capturedAt: DateTime(2026, 9, 12, 23, 59)),
        directRecord(name: 'After', capturedAt: DateTime(2026, 9, 13)),
        record('event-a'),
      ],
    );

    expect(records.map((item) => item.lead.name), [
      'Before',
      'Start',
      'End',
      'After',
    ]);
  });
}
