/// Small authenticated HTTP adapter for the versioned Foloo API.
///
/// It centralizes JSON, timeouts, bearer authorization and idempotency without
/// exposing network calls to screens. Media binaries are never accepted here.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'sync_models.dart';

class FolooApiConfiguration {
  const FolooApiConfiguration({required this.baseUrl});

  final String baseUrl;

  static const dev = FolooApiConfiguration(
    baseUrl: String.fromEnvironment(
      'FOLOO_API_BASE_URL',
      defaultValue: 'https://zbc91cpy10.execute-api.us-east-1.amazonaws.com',
    ),
  );
}

abstract interface class SyncHttpTransport {
  Future<SyncResponse> send({
    required Uri uri,
    required String method,
    required Map<String, String> headers,
    String? body,
    required Duration timeout,
  });
}

class IoSyncHttpTransport implements SyncHttpTransport {
  IoSyncHttpTransport({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<SyncResponse> send({
    required Uri uri,
    required String method,
    required Map<String, String> headers,
    String? body,
    required Duration timeout,
  }) async {
    try {
      final request = await _client.openUrl(method, uri).timeout(timeout);
      headers.forEach(request.headers.set);
      if (body != null) request.write(body);
      final response = await request.close().timeout(timeout);
      final responseBody = await utf8.decoder.bind(response).join();
      final retryAfter = _retryAfter(response.headers.value('retry-after'));
      return SyncResponse(
        statusCode: response.statusCode,
        data: responseBody.isEmpty ? null : jsonDecode(responseBody),
        retryAfter: retryAfter,
      );
    } on TimeoutException catch (error) {
      throw SyncTransportException(error.toString());
    } on SocketException catch (error) {
      throw SyncTransportException(error.message);
    } on HttpException catch (error) {
      throw SyncTransportException(error.message);
    } on FormatException catch (error) {
      throw SyncTransportException(error.message);
    }
  }

  Duration? _retryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value);
    if (seconds != null && seconds >= 0) return Duration(seconds: seconds);
    try {
      final date = HttpDate.parse(value);
      final delta = date.difference(DateTime.now().toUtc());
      return delta.isNegative ? Duration.zero : delta;
    } on FormatException {
      return null;
    }
  }
}

class FolooApiClient implements SyncApi {
  FolooApiClient({
    required FolooApiConfiguration configuration,
    SyncHttpTransport? transport,
    this.timeout = const Duration(seconds: 15),
  }) : _baseUri = Uri.parse(configuration.baseUrl),
       _transport = transport ?? IoSyncHttpTransport();

  final Uri _baseUri;
  final SyncHttpTransport _transport;
  final Duration timeout;

  @override
  Future<SyncResponse> send(String accessToken, SyncRequest request) async {
    final response = await _transport.send(
      uri: _baseUri.resolve(request.path),
      method: request.method,
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $accessToken',
        HttpHeaders.acceptHeader: 'application/json',
        if (request.body != null)
          HttpHeaders.contentTypeHeader: 'application/json',
        if (request.idempotencyKey != null)
          'Idempotency-Key': request.idempotencyKey!,
      },
      body: request.body == null ? null : jsonEncode(request.body),
      timeout: timeout,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SyncHttpException(
        response.statusCode,
        retryAfter: response.retryAfter,
      );
    }
    return response;
  }
}
