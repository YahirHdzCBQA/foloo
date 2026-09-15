/// Direct HTTPS transfer boundary for private S3 media.
///
/// Signed URLs are ephemeral and never persisted or logged. The durable outbox
/// retains only logical media identity and local private-file metadata.
library;

import 'dart:async';
import 'dart:io';

class MediaTransferException implements Exception {
  const MediaTransferException({this.statusCode, this.code = 'transport'});

  final int? statusCode;
  final String code;
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
      await response.drain<void>().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MediaTransferException(
          statusCode: response.statusCode,
          code: response.statusCode == 403 ? 'authorization_expired' : 'http',
        );
      }
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
    final extension = contentType == 'audio/m4a' ? '.m4a' : '.jpg';
    final destination = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'foloo_media_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    try {
      final request = await _client.getUrl(url).timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>().timeout(timeout);
        throw MediaTransferException(
          statusCode: response.statusCode,
          code: response.statusCode == 403 ? 'authorization_expired' : 'http',
        );
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
}
