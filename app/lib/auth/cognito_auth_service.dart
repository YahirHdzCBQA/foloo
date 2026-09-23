/// AWS Cognito implementation of the authentication boundary (AUT-01–AUT-13).
library;

import 'package:amplify_flutter/amplify_flutter.dart' as amplify;
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart' as cognito;

import 'auth_models.dart';
import 'auth_service.dart';

class CognitoIdentity {
  const CognitoIdentity({required this.sub, required this.username});

  final String sub;
  final String username;
}

class CognitoSignUpOutcome {
  const CognitoSignUpOutcome({required this.confirmationRequired});

  final bool confirmationRequired;
}

/// Injectable seam keeps unit/widget tests independent from live AWS users.
abstract interface class CognitoAuthClient {
  Future<CognitoIdentity?> restoreIdentity();

  Future<CognitoSignUpOutcome> signUp({
    required String email,
    required String password,
  });

  Future<void> confirmSignUp({required String email, required String code});

  Future<void> resendSignUpCode({required String email});

  Future<CognitoIdentity> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

abstract interface class CognitoSocialAuthClient {
  Future<CognitoIdentity> signInWithProvider(AuthProvider provider);
}

class AmplifyCognitoAuthClient
    implements CognitoAuthClient, CognitoSocialAuthClient {
  const AmplifyCognitoAuthClient();

  @override
  Future<CognitoIdentity?> restoreIdentity() async {
    try {
      final session = await amplify.Amplify.Auth.fetchAuthSession();
      if (!session.isSignedIn) return null;
      return await _currentIdentity();
    } on amplify.SignedOutException {
      return null;
    } on Object catch (error) {
      throw _mapAmplifyError(error, _AuthOperation.restore);
    }
  }

  @override
  Future<CognitoSignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final result = await amplify.Amplify.Auth.signUp(
        username: email,
        password: password,
        options: amplify.SignUpOptions(
          userAttributes: {amplify.AuthUserAttributeKey.email: email},
        ),
      );
      return CognitoSignUpOutcome(
        confirmationRequired: !result.isSignUpComplete,
      );
    } on Object catch (error) {
      throw _mapAmplifyError(error, _AuthOperation.signUp);
    }
  }

  @override
  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    try {
      final result = await amplify.Amplify.Auth.confirmSignUp(
        username: email,
        confirmationCode: code,
      );
      if (!result.isSignUpComplete) {
        throw const FolooAuthException(AuthFailureCode.unexpected);
      }
    } on Object catch (error) {
      if (error is FolooAuthException) rethrow;
      throw _mapAmplifyError(error, _AuthOperation.confirmSignUp);
    }
  }

  @override
  Future<void> resendSignUpCode({required String email}) async {
    try {
      await amplify.Amplify.Auth.resendSignUpCode(username: email);
    } on Object catch (error) {
      throw _mapAmplifyError(error, _AuthOperation.resendCode);
    }
  }

  @override
  Future<CognitoIdentity> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final result = await amplify.Amplify.Auth.signIn(
        username: email,
        password: password,
      );
      if (!result.isSignedIn) {
        if (result.nextStep.signInStep ==
            amplify.AuthSignInStep.confirmSignUp) {
          throw const FolooAuthException(AuthFailureCode.userNotConfirmed);
        }
        throw const FolooAuthException(AuthFailureCode.unexpected);
      }
      return await _currentIdentity();
    } on Object catch (error) {
      if (error is FolooAuthException) rethrow;
      throw _mapAmplifyError(error, _AuthOperation.signIn);
    }
  }

  @override
  Future<CognitoIdentity> signInWithProvider(AuthProvider provider) async {
    try {
      final amplifyProvider = switch (provider) {
        AuthProvider.google => amplify.AuthProvider.google,
        // The exact Cognito IdP name is externally configurable. Foloo uses
        // the approved product name and never borrows sender OAuth tokens.
        AuthProvider.microsoft => const amplify.AuthProvider.custom(
          'Microsoft',
        ),
      };

      final result = await amplify.Amplify.Auth.signInWithWebUI(
        provider: amplifyProvider,
        options: provider == AuthProvider.microsoft
            ? const amplify.SignInWithWebUIOptions(
                pluginOptions: cognito.CognitoSignInWithWebUIPluginOptions(
                  prompt: [cognito.CognitoSignInWithWebUIPrompt.selectAccount],
                ),
              )
            : const amplify.SignInWithWebUIOptions(),
      );

      if (!result.isSignedIn) {
        throw const FolooAuthException(AuthFailureCode.socialLoginUnavailable);
      }
      return await _currentIdentity();
    } on Object catch (error, stackTrace) {
      amplify.safePrint('=== SOCIAL LOGIN ERROR ===');
      amplify.safePrint('Provider: $provider');
      amplify.safePrint('Type: ${error.runtimeType}');
      amplify.safePrint('Error: $error');
      amplify.safePrint('StackTrace: $stackTrace');
      amplify.safePrint('==========================');

      if (error is FolooAuthException) rethrow;

      final mapped = _mapAmplifyError(error, _AuthOperation.socialSignIn);

      if (mapped.code == AuthFailureCode.unexpected ||
          mapped.code == AuthFailureCode.invalidInput) {
        throw const FolooAuthException(AuthFailureCode.socialLoginUnavailable);
      }

      throw mapped;
    }
  }

  Future<CognitoIdentity> _currentIdentity() async {
    final user = await amplify.Amplify.Auth.getCurrentUser();
    return CognitoIdentity(sub: user.userId, username: user.username);
  }

  @override
  Future<void> signOut() async {
    try {
      await amplify.Amplify.Auth.signOut();
    } on Object catch (error) {
      throw _mapAmplifyError(error, _AuthOperation.signOut);
    }
  }
}

class CognitoAuthService implements AuthService, SocialAuthService {
  const CognitoAuthService(this._client);

  final CognitoAuthClient _client;

  @override
  Future<AuthUser?> restoreSession() async {
    final identity = await _client.restoreIdentity();
    return identity == null ? null : _mapUser(identity);
  }

  @override
  Future<AuthSignUpResult> signUp({
    required String email,
    required String password,
  }) async {
    final result = await _client.signUp(
      email: email.trim().toLowerCase(),
      password: password,
    );
    return AuthSignUpResult(confirmationRequired: result.confirmationRequired);
  }

  @override
  Future<void> confirmSignUp({required String email, required String code}) =>
      _client.confirmSignUp(
        email: email.trim().toLowerCase(),
        code: code.trim(),
      );

  @override
  Future<void> resendSignUpCode({required String email}) =>
      _client.resendSignUpCode(email: email.trim().toLowerCase());

  @override
  Future<AuthUser> signIn({
    required String username,
    required String password,
  }) async => _mapUser(
    await _client.signIn(
      email: username.trim().toLowerCase(),
      password: password,
    ),
  );

  @override
  Future<AuthUser> signInWithProvider(AuthProvider provider) async {
    final client = _client;
    if (client is! CognitoSocialAuthClient) {
      throw const FolooAuthException(AuthFailureCode.socialLoginUnavailable);
    }
    return _mapUser(
      await (client as CognitoSocialAuthClient).signInWithProvider(provider),
    );
  }

  @override
  Future<void> signOut() => _client.signOut();

  static AuthUser _mapUser(CognitoIdentity identity) =>
      AuthUser(id: identity.sub, username: identity.username);
}

enum _AuthOperation {
  restore,
  signUp,
  confirmSignUp,
  resendCode,
  signIn,
  socialSignIn,
  signOut,
}

FolooAuthException _mapAmplifyError(Object error, _AuthOperation operation) {
  if (error is amplify.NetworkException) {
    return const FolooAuthException(AuthFailureCode.network);
  }
  if (error is amplify.AuthValidationException) {
    return const FolooAuthException(AuthFailureCode.invalidInput);
  }
  if (error is amplify.AuthNotAuthorizedException) {
    return const FolooAuthException(AuthFailureCode.invalidCredentials);
  }

  final providerType = error.runtimeType.toString();
  return FolooAuthException(switch (providerType) {
    'UsernameExistsException' ||
    'AliasExistsException' => AuthFailureCode.emailAlreadyRegistered,
    'InvalidPasswordException' => AuthFailureCode.weakPassword,
    'CodeMismatchException' => AuthFailureCode.invalidConfirmationCode,
    'ExpiredCodeException' => AuthFailureCode.expiredConfirmationCode,
    'UserNotConfirmedException' => AuthFailureCode.userNotConfirmed,
    'LimitExceededException' ||
    'TooManyRequestsException' ||
    'TooManyFailedAttemptsException' => AuthFailureCode.rateLimited,
    'InvalidParameterException' => AuthFailureCode.invalidInput,
    'NotAuthorizedException' || 'NotAuthorizedServiceException'
        when operation == _AuthOperation.confirmSignUp =>
      AuthFailureCode.alreadyConfirmed,
    'NotAuthorizedException' ||
    'NotAuthorizedServiceException' ||
    'UserNotFoundException' => AuthFailureCode.invalidCredentials,
    _ => AuthFailureCode.unexpected,
  });
}
