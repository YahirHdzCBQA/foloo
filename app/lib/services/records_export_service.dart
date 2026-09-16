/// Builds owner/event-scoped Records exports and shares one private temp file.
///
/// The service owns the exact REG-09–REG-13 column contract. It never includes
/// technical identifiers, sync metadata, media paths or binary content.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:excel_community/excel_community.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_event.dart';
import '../models/lead_draft.dart';
import '../models/session_lead.dart';

enum RecordsExportFormat { xlsx, csv }

class RecordsExportLabels {
  const RecordsExportLabels({
    required this.headers,
    required this.customer,
    required this.partner,
    required this.supplier,
    required this.low,
    required this.medium,
    required this.high,
    required this.event,
    required this.direct,
  });

  final List<String> headers;
  final String customer;
  final String partner;
  final String supplier;
  final String low;
  final String medium;
  final String high;
  final String event;
  final String direct;
}

class RecordsExportFile {
  const RecordsExportFile({
    required this.filename,
    required this.bytes,
    required this.mimeType,
  });

  final String filename;
  final Uint8List bytes;
  final String mimeType;
}

/// Pure generator kept separate from platform sharing for deterministic tests.
class RecordsExportService {
  const RecordsExportService();

  RecordsExportFile build({
    required AppEvent event,
    required List<SessionLead> records,
    required RecordsExportFormat format,
    required RecordsExportLabels labels,
    DateTime? generatedAt,
  }) {
    if (labels.headers.length != 13) {
      throw ArgumentError.value(labels.headers.length, 'headers');
    }
    final rows = records
        .where((record) => record.lead.eventLocalId == event.id)
        .map((record) => _row(record, event, labels))
        .toList();
    final extension = format.name;
    final day = _date((generatedAt ?? DateTime.now()).toLocal());
    final filename = 'foloo_${_safeFilename(event.name)}_$day.$extension';
    if (format == RecordsExportFormat.csv) {
      final text = <List<String>>[
        labels.headers,
        ...rows,
      ].map((row) => row.map(_csvCell).join(',')).join('\r\n');
      return RecordsExportFile(
        filename: filename,
        bytes: Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]),
        mimeType: 'text/csv',
      );
    }
    final workbook = Excel.createExcel();
    final sheet = workbook['Records'];
    sheet.appendRow(labels.headers.map(TextCellValue.new).toList());
    for (final row in rows) {
      sheet.appendRow(row.map(TextCellValue.new).toList());
    }
    if (workbook.tables.containsKey('Sheet1')) workbook.delete('Sheet1');
    final bytes = workbook.save();
    if (bytes == null) throw StateError('Could not generate XLSX.');
    return RecordsExportFile(
      filename: filename,
      bytes: Uint8List.fromList(bytes),
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  List<String> _row(
    SessionLead record,
    AppEvent event,
    RecordsExportLabels labels,
  ) => [
    _timestamp(record.capturedAt),
    record.lead.name,
    record.lead.lastName,
    record.lead.role,
    record.lead.company,
    record.lead.email,
    record.lead.phone,
    switch (record.lead.type) {
      LeadType.customer => labels.customer,
      LeadType.partner => labels.partner,
      LeadType.supplier => labels.supplier,
    },
    switch (record.lead.interest) {
      InterestLevel.low => labels.low,
      InterestLevel.medium => labels.medium,
      InterestLevel.high => labels.high,
    },
    record.lead.originKind == LeadOriginKind.event
        ? labels.event
        : labels.direct,
    event.name,
    record.lead.originKind == LeadOriginKind.direct
        ? (record.lead.place ?? '')
        : '',
    record.lead.note,
  ];

  String _timestamp(DateTime value) {
    final local = value.toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final totalMinutes = offset.inMinutes.abs();
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    return '${_date(local)}T${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}:'
        '${local.second.toString().padLeft(2, '0')}$sign$hours:$minutes';
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _safeFilename(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return sanitized.isEmpty ? 'evento' : sanitized;
  }

  String _csvCell(String value) {
    if (!value.contains(RegExp('[,"\r\n]'))) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}

abstract interface class RecordsFileSharer {
  Future<void> share(RecordsExportFile file, {Rect? origin});
}

/// Writes only to the app temp area and removes the file after the share sheet.
class DeviceRecordsFileSharer implements RecordsFileSharer {
  const DeviceRecordsFileSharer();

  @override
  Future<void> share(RecordsExportFile file, {Rect? origin}) async {
    final root = await getTemporaryDirectory();
    final directory = Directory('${root.path}/foloo_exports');
    await directory.create(recursive: true);
    final output = File('${directory.path}/${file.filename}');
    await output.writeAsBytes(file.bytes, flush: true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(output.path, mimeType: file.mimeType)],
          sharePositionOrigin: origin,
        ),
      );
    } finally {
      if (await output.exists()) await output.delete();
    }
  }
}
