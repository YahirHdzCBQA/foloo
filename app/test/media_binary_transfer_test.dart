/// Contract tests for Foloo's direct S3 binary transport.
///
/// A loopback server observes the real Dart HttpClient request without using
/// AWS credentials, presigned URLs or external network access (SYN-06/10).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/sync/media_binary_transfer.dart';

void main() {
  test('SYN-10 upload sends exact signed headers, length and bytes', () async {
    final file = await _temporaryFile([0xff, 0xd8, 0xff, 1, 2, 3]);
    addTearDown(() => file.parent.delete(recursive: true));
    final observed =
        Completer<({Map<String, String> headers, List<int> body})>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    server.listen((request) async {
      final body = await request.fold<List<int>>(
        <int>[],
        (bytes, chunk) => bytes..addAll(chunk),
      );
      observed.complete((
        headers: {
          'content-type': request.headers.value('content-type') ?? '',
          'content-length': request.headers.value('content-length') ?? '',
          'x-amz-meta-foloo-media-id':
              request.headers.value('x-amz-meta-foloo-media-id') ?? '',
        },
        body: body,
      ));
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
    });

    await IoMediaBinaryTransfer().upload(
      url: Uri.parse('http://127.0.0.1:${server.port}/upload'),
      headers: const {
        'content-type': 'image/jpeg',
        'x-amz-meta-foloo-media-id': '63b21d9f-8532-4ca0-b45e-cf8336bb807c',
      },
      localPath: file.path,
    );

    final request = await observed.future;
    expect(request.headers, {
      'content-type': 'image/jpeg',
      'content-length': '6',
      'x-amz-meta-foloo-media-id': '63b21d9f-8532-4ca0-b45e-cf8336bb807c',
    });
    expect(request.body, [0xff, 0xd8, 0xff, 1, 2, 3]);
  });

  for (final expectation in const [
    ('SignatureDoesNotMatch', 'signature_mismatch'),
    ('RequestExpired', 'authorization_expired'),
    ('ExpiredToken', 'authorization_expired'),
    ('AccessDenied', 'access_denied'),
  ]) {
    test('SYN-06 maps S3 ${expectation.$1} safely', () async {
      final error = await _s3Failure(expectation.$1);
      expect(error.statusCode, HttpStatus.forbidden);
      expect(error.storageCode, expectation.$1);
      expect(error.code, expectation.$2);
    });
  }
}

Future<File> _temporaryFile(List<int> bytes) async {
  final directory = await Directory.systemTemp.createTemp('foloo_s3_put_');
  return File('${directory.path}/media.bin')..writeAsBytesSync(bytes);
}

Future<MediaTransferException> _s3Failure(String storageCode) async {
  final file = await _temporaryFile([1]);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    await request.drain<void>();
    request.response
      ..statusCode = HttpStatus.forbidden
      ..headers.contentType = ContentType('application', 'xml')
      ..write(
        '<Error><Code>$storageCode</Code><Message>redacted</Message></Error>',
      );
    await request.response.close();
  });
  try {
    await IoMediaBinaryTransfer().upload(
      url: Uri.parse('http://127.0.0.1:${server.port}/upload'),
      headers: const {'content-type': 'application/octet-stream'},
      localPath: file.path,
    );
    throw StateError('Expected S3 failure.');
  } on MediaTransferException catch (error) {
    return error;
  } finally {
    await server.close(force: true);
    await file.parent.delete(recursive: true);
  }
}
