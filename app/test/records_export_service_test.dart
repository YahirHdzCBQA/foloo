import 'dart:convert';

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/models/app_event.dart';
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

SessionLead record(String eventId, {String name = 'José, "Pepe"'}) =>
    SessionLead(
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
      ),
    );

void main() {
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
        record('event-a'),
        record('event-b', name: 'Excluded'),
      ],
      format: RecordsExportFormat.csv,
      labels: labels,
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
    expect(text.split('\r\n').first.split(','), hasLength(13));
    expect(
      text,
      contains(RegExp(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}')),
    );
  });

  test('REG-09 XLSX is real, Unicode-safe and follows the 13-column order', () {
    final file = const RecordsExportService().build(
      event: event,
      records: [record('event-a')],
      format: RecordsExportFormat.xlsx,
      labels: labels,
      generatedAt: DateTime(2026, 9, 15),
    );
    expect(file.bytes.take(2), [0x50, 0x4B]);
    final workbook = Excel.decodeBytes(file.bytes);
    final rows = workbook.tables['Records']!.rows;
    expect(rows.first.map((cell) => cell?.value.toString()), labels.headers);
    expect(rows[1], hasLength(13));
    expect(rows[1][1]?.value.toString(), 'José, "Pepe"');
    expect(rows[1][4]?.value.toString(), 'Niñez\nMéxico');
  });
}
