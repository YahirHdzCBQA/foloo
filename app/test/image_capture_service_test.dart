import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/services/image_capture_service.dart';

void main() {
  test('OCR-10 non-Android recovery is a silent no-op', () async {
    final service = DeviceImageCaptureService(supportsLostDataRecovery: false);

    expect(await service.retrieveLostImage(), isNull);
  });
}
