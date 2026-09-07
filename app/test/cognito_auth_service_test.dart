import 'dart:convert';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foloo/auth/auth_models.dart';
import 'package:foloo/auth/auth_repository.dart';
import 'package:foloo/auth/cognito_auth_service.dart';
import 'package:foloo/auth/cognito_configuration.dart';

class _FakeCognitoClient implements CognitoAuthClient {
  CognitoIdentity? restored;
  CognitoIdentity signedIn = const CognitoIdentity(
    sub: 'cognito-sub-123',
    username: 'seller@example.com',
  );
  FolooAuthException? signInFailure;
  FolooAuthException? confirmationFailure;
  bool confirmationRequired = true;
  bool signedOut = false;
  String? signUpEmail;
  String? confirmedCode;
  String? resentEmail;

  @override
  Future<CognitoIdentity?> restoreIdentity() async => restored;

  @override
  Future<CognitoSignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    signUpEmail = email;
    return CognitoSignUpOutcome(confirmationRequired: confirmationRequired);
  }

  @override
  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    final failure = confirmationFailure;
    if (failure != null) throw failure;
    confirmedCode = code;
  }

  @override
  Future<void> resendSignUpCode({required String email}) async {
    resentEmail = email;
  }

  @override
  Future<CognitoIdentity> signIn({
    required String email,
    required String password,
  }) async {
    final failure = signInFailure;
    if (failure != null) throw failure;
    return signedIn;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

void main() {
  test('AUT-12 DEV configuration has public User Pool identifiers only', () {
    final decoded = jsonDecode(
      CognitoConfigurations.dev.toAmplifyConfiguration(),
    ) as Map<String, Object?>;
    final outputs = AmplifyOutputs.fromJson(decoded);

    expect(outputs.auth?.awsRegion, 'us-east-1');
    expect(outputs.auth?.userPoolId, 'us-east-1_QVm3dWe4O');
    expect(outputs.auth?.userPoolClientId, '6jong3atp2crqcsde6g215ant8');
    expect(outputs.auth?.identityPoolId, isNull);
    expect(decoded['auth'], isNot(contains('app_client_secret')));
  });

  test('AUT-02 restores a Cognito session and maps sub as owner id', () async {
    final client = _FakeCognitoClient()
      ..restored = const CognitoIdentity(
        sub: 'stable-sub',
        username: 'restored@example.com',
      );
    final repository = AuthRepository(CognitoAuthService(client));

    await repository.initialize();

    expect(repository.state.status, AuthStatus.authenticated);
    expect(repository.state.user?.id, 'stable-sub');
    expect(repository.state.user?.username, 'restored@example.com');
  });

  test(
    'AUT-10/AUT-11 sign-up, confirmation and resend stay normalized',
    () async {
      final client = _FakeCognitoClient();
      final repository = AuthRepository(CognitoAuthService(client));
      await repository.initialize();

      final signUp = await repository.signUp(
        email: ' Seller@Example.COM ',
        password: 'Strong-password-1',
      );
      expect(signUp?.confirmationRequired, isTrue);
      expect(client.signUpEmail, 'seller@example.com');

      expect(
        await repository.confirmSignUp(
          email: 'Seller@Example.COM',
          code: ' 123456 ',
        ),
        isTrue,
      );
      expect(client.confirmedCode, '123456');

      expect(
        await repository.resendSignUpCode(email: 'Seller@Example.COM'),
        isTrue,
      );
      expect(client.resentEmail, 'seller@example.com');
    },
  );

  test('AUT-11 exposes invalid confirmation code without AWS text', () async {
    final client = _FakeCognitoClient()
      ..confirmationFailure = const FolooAuthException(
        AuthFailureCode.invalidConfirmationCode,
      );
    final repository = AuthRepository(CognitoAuthService(client));

    expect(
      await repository.confirmSignUp(
        email: 'seller@example.com',
        code: '000000',
      ),
      isFalse,
    );
    expect(repository.failure, AuthFailureCode.invalidConfirmationCode);
  });

  test(
    'AUT-01 reports login failure and maps successful Cognito user',
    () async {
      final client = _FakeCognitoClient()
        ..signInFailure = const FolooAuthException(
          AuthFailureCode.invalidCredentials,
        );
      final repository = AuthRepository(CognitoAuthService(client));

      expect(
        await repository.signIn(
          username: 'seller@example.com',
          password: 'bad',
        ),
        isFalse,
      );
      expect(repository.failure, AuthFailureCode.invalidCredentials);

      client.signInFailure = null;
      expect(
        await repository.signIn(
          username: 'seller@example.com',
          password: 'valid',
        ),
        isTrue,
      );
      expect(repository.state.user?.id, 'cognito-sub-123');
    },
  );

  test(
    'AUT-08 logout changes auth state without touching product data',
    () async {
      final client = _FakeCognitoClient();
      final repository = AuthRepository(CognitoAuthService(client));
      await repository.signIn(
        username: 'seller@example.com',
        password: 'valid',
      );

      await repository.signOut();

      expect(client.signedOut, isTrue);
      expect(repository.state.status, AuthStatus.unauthenticated);
    },
  );
}
