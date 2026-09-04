import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/l10n/app_localizations.dart';
import 'package:foloo/screens/multi_photo_capture_screen.dart';
import 'package:foloo/services/contact_image_picker_service.dart';
import 'package:foloo/theme/foloo_theme.dart';
import 'package:image/image.dart' as image_codec;
import 'package:image_picker/image_picker.dart';

class _FakeCameraPicker implements ContactImagePickerService {
  var calls = 0;

  @override
  Future<PickedContactImage?> pick(ImageSource source) async {
    calls++;
    return PickedContactImage(
      path: '/tmp/multi-photo-$calls.png',
      bytes: image_codec.encodePng(image_codec.Image(width: 2, height: 2)),
    );
  }
}

class _PhotoSessionHost extends StatefulWidget {
  const _PhotoSessionHost({
    required this.picker,
    this.initialImages = const [],
  });

  final ContactImagePickerService picker;
  final List<PickedContactImage> initialImages;

  @override
  State<_PhotoSessionHost> createState() => _PhotoSessionHostState();
}

class _PhotoSessionHostState extends State<_PhotoSessionHost> {
  List<PickedContactImage>? result;

  Future<void> _open() async {
    final images = await Navigator.push<List<PickedContactImage>>(
      context,
      MaterialPageRoute(
        builder: (_) => MultiPhotoCaptureScreen(
          initialImages: widget.initialImages,
          picker: widget.picker,
        ),
      ),
    );
    if (mounted) setState(() => result = images);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const Key('openPhotoSession'),
        onPressed: _open,
        child: Text('result:${result?.length ?? -1}'),
      ),
    ),
  );
}

Widget app(ContactImagePickerService picker, {int initialCount = 0}) {
  final initial = List.generate(
    initialCount,
    (index) => PickedContactImage(
      path: '/tmp/existing-$index.png',
      bytes: image_codec.encodePng(image_codec.Image(width: 2, height: 2)),
    ),
  );
  return MaterialApp(
    theme: FolooTheme.light,
    locale: const Locale('es'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: _PhotoSessionHost(picker: picker, initialImages: initial),
  );
}

void main() {
  for (final target in [1, 2, 3]) {
    testWidgets(
      'CAP-23 captures and confirms $target photo(s) in one session',
      (tester) async {
        final picker = _FakeCameraPicker();
        await tester.pumpWidget(app(picker));
        await tester.tap(find.byKey(const Key('openPhotoSession')));
        await tester.pumpAndSettle();

        for (var count = 1; count < target; count++) {
          await tester.tap(
            find.byKey(const Key('captureAnotherReferencePhoto')),
          );
          await tester.pumpAndSettle();
        }

        expect(find.text('$target de 3'), findsOneWidget);
        expect(picker.calls, target);
        if (target == 3) {
          expect(
            tester
                .widget<IconButton>(
                  find.byKey(const Key('captureAnotherReferencePhoto')),
                )
                .onPressed,
            isNull,
          );
        }
        await tester.tap(find.byKey(const Key('finishMultiPhotoSession')));
        await tester.pumpAndSettle();
        expect(find.text('result:$target'), findsOneWidget);
      },
    );
  }

  testWidgets('CAP-23 later session only fills the one remaining slot', (
    tester,
  ) async {
    final picker = _FakeCameraPicker();
    await tester.pumpWidget(app(picker, initialCount: 2));
    await tester.tap(find.byKey(const Key('openPhotoSession')));
    await tester.pumpAndSettle();

    expect(find.text('3 de 3'), findsOneWidget);
    expect(picker.calls, 1);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const Key('captureAnotherReferencePhoto')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('finishMultiPhotoSession')));
    await tester.pumpAndSettle();
    expect(find.text('result:3'), findsOneWidget);
  });
}
