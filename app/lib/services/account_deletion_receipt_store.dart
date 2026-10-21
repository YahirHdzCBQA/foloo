/// Platform-protected storage for the opaque Account Deletion receipt.
///
/// The receipt contains no email or profile data and remains available after
/// Cognito logout so the user can query completion status (AUT-21/RNF-09).
library;

import 'dart:convert';

import 'package:amplify_secure_storage/amplify_secure_storage.dart';

import 'account_deletion_service.dart';

class AccountDeletionReceiptStore {
  AccountDeletionReceiptStore()
    // The package is already used transitively by Amplify Auth. A separate
    // scope prevents deletion-status receipts from mixing with auth tokens.
    // ignore: invalid_use_of_internal_member
    : _storage = AmplifySecureStorage(
        config: AmplifySecureStorageConfig(
          scope: 'foloo_account_deletion_receipts',
        ),
      );

  final SecureStorageInterface _storage;

  Future<void> save(AccountDeletionAccepted accepted) async {
    await _storage.write(
      key: 'current',
      value: jsonEncode({
        'requestId': accepted.requestId,
        'receipt': accepted.receipt,
        'status': accepted.status.name,
      }),
    );
  }

  Future<Map<String, String>?> read() async {
    final value = await _storage.read(key: 'current');
    if (value == null) return null;
    final decoded = jsonDecode(value);
    if (decoded is! Map) return null;
    final requestId = decoded['requestId'];
    final receipt = decoded['receipt'];
    if (requestId is! String || receipt is! String) return null;
    return {'requestId': requestId, 'receipt': receipt};
  }

  Future<void> clear() async {
    await _storage.delete(key: 'current');
  }
}
