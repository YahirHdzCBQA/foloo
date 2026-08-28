/// Native PDF-selection boundary for the Pro content library.
///
/// It selects one local PDF and returns metadata only. Uploading, caching and
/// backend persistence remain outside this frontend task (CON-02, CON-13).
library;

import 'package:file_picker/file_picker.dart';

/// Local metadata returned by the operating system document picker.
class PickedPdf {
  const PickedPdf({required this.name, required this.byteSize, this.localPath});

  final String name;
  final int byteSize;
  final String? localPath;

  String get sizeLabel {
    if (byteSize >= 1024 * 1024) {
      return '${(byteSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(byteSize / 1024).ceil()} KB';
  }
}

/// Opens the platform document browser with a PDF-only filter.
abstract interface class PdfPickerService {
  Future<PickedPdf?> pickPdf();
}

class DevicePdfPickerService implements PdfPickerService {
  const DevicePdfPickerService();

  @override
  Future<PickedPdf?> pickPdf() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (file == null) return null;
    if (!file.name.toLowerCase().endsWith('.pdf')) return null;
    return PickedPdf(
      name: file.name,
      byteSize: await file.length(),
      localPath: file.path,
    );
  }
}
