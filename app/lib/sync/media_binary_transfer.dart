/// Direct HTTPS transfer boundary for private S3 media.
///
/// Signed URLs are ephemeral and never persisted or logged. The durable outbox
/// retains only logical media identity and local private-file metadata.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MediaTransferException implements Exception {
  const MediaTransferException({
    this.statusCode,
    this.code = 'transport',
    this.storageCode,
  });

  final int? statusCode;
  final String code;
  final String? storageCode;
}

abstract interface class MediaBinaryTransfer {
  Future<void> upload({
    required Uri url,
    required Map<String, String> headers,
    required String localPath,
  });

  Future<String> download({required Uri url, required String contentType});
}

class IoMediaBinaryTransfer implements MediaBinaryTransfer {
  IoMediaBinaryTransfer({
    HttpClient? client,
    this.timeout = const Duration(seconds: 60),
  }) : _client = client ?? HttpClient();

  final HttpClient _client;
  final Duration timeout;

  @override
  Future<void> upload({
    required Uri url,
    required Map<String, String> headers,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw const MediaTransferException(code: 'local_file_missing');
    }
    try {
      final request = await _client.putUrl(url).timeout(timeout);
      headers.forEach(request.headers.set);
      request.contentLength = await file.length();
      final response = await file.openRead().pipe(request).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _throwStorageError(response).timeout(timeout);
      }
      await response.drain<void>().timeout(timeout);
    } on MediaTransferException {
      rethrow;
    } on TimeoutException {
      throw const MediaTransferException(code: 'timeout');
    } on SocketException {
      throw const MediaTransferException();
    } on HttpException {
      throw const MediaTransferException();
    }
  }

  @override
  Future<String> download({
    required Uri url,
    required String contentType,
  }) async {
    final extension = contentType == 'application/pdf'
        ? '.pdf'
        : contentType == 'audio/m4a'
        ? '.m4a'
        : '.jpg';
    final destination = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'foloo_media_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    try {
      final request = await _client.getUrl(url).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _throwStorageError(response).timeout(timeout);
      }
      await response.pipe(destination.openWrite()).timeout(timeout);
      return destination.path;
    } on MediaTransferException {
      if (await destination.exists()) await destination.delete();
      rethrow;
    } on TimeoutException {
      if (await destination.exists()) await destination.delete();
      throw const MediaTransferException(code: 'timeout');
    } on SocketException {
      if (await destination.exists()) await destination.delete();
      throw const MediaTransferException();
    } on HttpException {
      if (await destination.exists()) await destination.delete();
      throw const MediaTransferException();
    }
  }

  Future<Never> _throwStorageError(HttpClientResponse response) async {
    final body = await utf8.decoder.bind(response).join();
    final storageCode = RegExp(r'<Code>\s*([A-Za-z0-9]+)\s*</Code>')
        .firstMatch(body)
        ?.group(1);
    final safeStorageCode =
        const {
          'ExpiredToken',
          'RequestExpired',
          'SignatureDoesNotMatch',
          'AccessDenied',
          'BadDigest',
          'InvalidRequest',
        }.contains(storageCode)
        ? storageCode
        : null;
    final code = switch (safeStorageCode) {
      'ExpiredToken' || 'RequestExpired' => 'authorization_expired',
      'SignatureDoesNotMatch' => 'signature_mismatch',
      'AccessDenied' => 'access_denied',
      'BadDigest' => 'checksum_mismatch',
      'InvalidRequest' => 'invalid_request',
      _ => response.statusCode == 403 ? 's3_forbidden' : 'http',
    };
    throw MediaTransferException(
      statusCode: response.statusCode,
      code: code,
      storageCode: safeStorageCode,
    );
  }
}
