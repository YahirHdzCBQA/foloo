/// Safe mobile client for email connection metadata and OAuth launch.
///
/// Provider tokens never cross this boundary; only provider, masked sender and
/// connection state are exposed to Flutter (SAL-04/SAL-08).
library;

import 'package:url_launcher/url_launcher.dart';

import '../sync/sync_models.dart';

class EmailConnectionView {
  const EmailConnectionView({
    required this.id,
    required this.provider,
    required this.senderAddress,
    required this.status,
  });

  final String id;
  final String provider;
  final String senderAddress;
  final String status;
}

class EmailConnectionService {
  const EmailConnectionService(this._api, this._session);

  final SyncApi _api;
  final SyncSessionProvider _session;

  Future<EmailConnectionView?> status(String owner) async {
    final token = await _session.accessTokenFor(owner);
    if (token == null) return null;
    final response = await _api.send(
      token,
      const SyncRequest(method: 'GET', path: '/v1/email/connection'),
    );
    final envelope = response.data;
    final raw = envelope is Map ? envelope['data'] : null;
    if (raw is! Map) return null;
    return EmailConnectionView(
      id: raw['id'] as String,
      provider: raw['provider'] as String,
      senderAddress: raw['senderAddress'] as String,
      status: raw['status'] as String,
    );
  }

  Future<bool> connect(String owner, String provider) async {
    final token = await _session.accessTokenFor(owner);
    if (token == null) return false;
    final response = await _api.send(
      token,
      SyncRequest(method: 'POST', path: '/v1/email/connection/$provider'),
    );
    final envelope = response.data;
    final raw = envelope is Map ? envelope['data'] : null;
    final url = raw is Map ? raw['authorizationUrl'] as String? : null;
    if (url == null) return false;
    return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> disconnect(String owner) async {
    final token = await _session.accessTokenFor(owner);
    if (token == null) return;
    await _api.send(
      token,
      const SyncRequest(method: 'DELETE', path: '/v1/email/connection'),
    );
  }
}
