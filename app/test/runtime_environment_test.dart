/// Verifies that public release configuration cannot fall back to AWS DEV.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/config/runtime_environment.dart';

void main() {
  test('INF-04 Debug without a selector preserves DEV', () {
    final configuration = FolooRuntimeEnvironment.fromBuild(
      environment: '',
      isRelease: false,
    );

    expect(configuration.name, FolooEnvironment.dev);
  });

  test('INF-04 Release requires an explicit environment', () {
    expect(
      () => FolooRuntimeEnvironment.fromBuild(environment: '', isRelease: true),
      throwsStateError,
    );
  });

  test('INF-04 DEV Release requires the separate QA opt-in', () {
    expect(
      () => FolooRuntimeEnvironment.fromBuild(
        environment: 'dev',
        isRelease: true,
      ),
      throwsStateError,
    );
    expect(
      FolooRuntimeEnvironment.fromBuild(
        environment: 'dev',
        isRelease: true,
        allowDevRelease: true,
      ).name,
      FolooEnvironment.dev,
    );
  });

  test('INF-04 PROD requires complete non-DEV public identifiers', () {
    expect(
      () => FolooRuntimeEnvironment.fromBuild(
        environment: 'prod',
        isRelease: true,
      ),
      throwsStateError,
    );
    expect(
      () => FolooRuntimeEnvironment.fromBuild(
        environment: 'prod',
        isRelease: true,
        prodRegion: 'us-east-1',
        prodUserPoolId: 'us-east-1_QVm3dWe4O',
        prodAppClientId: 'fixture-prod-client',
        prodHostedUiDomain: 'fixture.auth.us-east-1.amazoncognito.com',
        prodApiBaseUrl: 'https://fixture.execute-api.us-east-1.amazonaws.com',
      ),
      throwsStateError,
    );
  });

  test('INF-04 PROD rejects the DEV API even with a trailing slash', () {
    expect(
      () => FolooRuntimeEnvironment.fromBuild(
        environment: 'prod',
        isRelease: true,
        prodRegion: 'us-east-1',
        prodUserPoolId: 'us-east-1_ProdFixture1',
        prodAppClientId: 'fixture-prod-client',
        prodHostedUiDomain: 'fixture.auth.us-east-1.amazoncognito.com',
        prodApiBaseUrl:
            'https://zbc91cpy10.execute-api.us-east-1.amazonaws.com/',
      ),
      throwsStateError,
    );
  });

  test('INF-04 PROD accepts an isolated complete configuration', () {
    final configuration = FolooRuntimeEnvironment.fromBuild(
      environment: 'prod',
      isRelease: true,
      prodRegion: 'us-west-2',
      prodUserPoolId: 'us-west-2_ProdFixture1',
      prodAppClientId: 'fixture-prod-client',
      prodHostedUiDomain: 'fixture.auth.us-west-2.amazoncognito.com',
      prodApiBaseUrl: 'https://fixture.execute-api.us-west-2.amazonaws.com/',
    );

    expect(configuration.name, FolooEnvironment.prod);
    expect(
      configuration.apiBaseUrl,
      'https://fixture.execute-api.us-west-2.amazonaws.com',
    );
  });

  test(
    'INF-04 PROD Cognito identifiers must belong to the selected region',
    () {
      expect(
        () => FolooRuntimeEnvironment.fromBuild(
          environment: 'prod',
          isRelease: true,
          prodRegion: 'us-west-2',
          prodUserPoolId: 'us-east-2_ProdFixture1',
          prodAppClientId: 'fixture-prod-client',
          prodHostedUiDomain: 'fixture.auth.us-west-2.amazoncognito.com',
          prodApiBaseUrl: 'https://fixture.execute-api.us-west-2.amazonaws.com',
        ),
        throwsStateError,
      );
    },
  );
}
