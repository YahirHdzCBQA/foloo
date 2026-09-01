/// Native image-selection boundary for optional Pro contact-reference media.
///
/// The interface keeps CAP-22 testable without coupling capture state to the
/// image_picker platform channel.
library;

import 'package:image_picker/image_picker.dart';

class PickedContactImage {
  const PickedContactImage({required this.path, required this.bytes});

  final String path;
  final List<int> bytes;
}

abstract interface class ContactImagePickerService {
  Future<PickedContactImage?> pick(ImageSource source);
}

class DeviceContactImagePickerService implements ContactImagePickerService {
  DeviceContactImagePickerService([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedContactImage?> pick(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      maxWidth: 1568,
      maxHeight: 1568,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (image == null) return null;
    return PickedContactImage(
      path: image.path,
      bytes: await image.readAsBytes(),
    );
  }
}
