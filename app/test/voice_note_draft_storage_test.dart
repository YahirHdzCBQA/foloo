import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/services/voice_note_service.dart';

void main() {
  test(
    'VOZ-04 keeps pre-save voice drafts in app-private support storage',
    () async {
      final support = await Directory.systemTemp.createTemp('foloo-support-');
      addTearDown(() async {
        if (await support.exists()) await support.delete(recursive: true);
      });

      final drafts = await prepareVoiceNoteDraftDirectory(() async => support);
      final draft = File('${drafts.path}${Platform.pathSeparator}note.m4a');
      await draft.writeAsBytes(const [1, 2, 3]);

      expect(drafts.path, startsWith(support.path));
      expect(
        drafts.path,
        contains('foloo_media${Platform.pathSeparator}drafts'),
      );
      expect(await draft.exists(), isTrue);

      // Re-entering the flow reuses the same private directory and does not
      // delete the stopped draft; only explicit discard/promotion owns cleanup.
      final reopened = await prepareVoiceNoteDraftDirectory(
        () async => support,
      );
      expect(reopened.path, drafts.path);
      expect(await draft.exists(), isTrue);
    },
  );
}
