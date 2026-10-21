/// Selectively purges one owner's Drift rows and managed private files.
///
/// It never deletes global authentication bootstrap data or another owner's
/// rows. Callers invoke it only after backend acceptance (SYN-11/SYN-12).
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../data/local/app_database.dart';
import '../data/local/private_media_storage.dart';

class LocalAccountDeletionPurger {
  const LocalAccountDeletionPurger(this.database, this.mediaStorage);

  final AppDatabase database;
  final PrivateMediaStorage mediaStorage;

  Future<void> purge(String ownerSub) async {
    final mediaRows = await database
        .customSelect(
          '''SELECT m.local_path
         FROM local_lead_media m
         JOIN local_leads l ON l.local_id = m.lead_local_id
         WHERE l.owner_user_id = ?''',
          variables: [Variable.withString(ownerSub)],
        )
        .get();
    final contentRows = await database
        .customSelect(
          'SELECT local_path FROM local_content_files '
          'WHERE owner_user_id = ? AND local_path IS NOT NULL',
          variables: [Variable.withString(ownerSub)],
        )
        .get();
    final preferenceRows = await database
        .customSelect(
          "SELECT value AS local_path FROM local_user_preferences "
          "WHERE owner_user_id = ? AND key = 'profilePhotoLocalPath'",
          variables: [Variable.withString(ownerSub)],
        )
        .get();
    final paths = [
      ...mediaRows,
      ...contentRows,
      ...preferenceRows,
    ].map((row) => row.read<String>('local_path')).toSet();

    await database.transaction(() async {
      await _delete('local_email_send_intents', ownerSub);
      await _delete('local_email_follow_ups', ownerSub);
      await _delete('local_email_connections', ownerSub);
      await _delete('local_event_email_templates', ownerSub);
      await _delete('local_email_templates', ownerSub);
      await _delete('local_trial_reservations', ownerSub);
      await _delete('local_entitlements', ownerSub);
      await _delete('sync_operations', ownerSub);
      await _delete('local_content_files', ownerSub);
      await _delete('local_leads', ownerSub);
      await _delete('local_events', ownerSub);
      await _delete('local_profiles', ownerSub);
      await _delete('local_user_preferences', ownerSub);
    });

    final root = p.canonicalize(mediaStorage.root.absolute.path);
    for (final path in paths) {
      final candidate = p.canonicalize(File(path).absolute.path);
      if (!p.isWithin(root, candidate)) continue;
      final file = File(candidate);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _delete(String table, String ownerSub) =>
      database.customStatement('DELETE FROM $table WHERE owner_user_id = ?', [
        ownerSub,
      ]);
}
