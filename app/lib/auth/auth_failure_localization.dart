/// Localized, provider-neutral authentication feedback (AUT-11).
library;

import '../l10n/app_localizations.dart';
import 'auth_models.dart';

String localizedAuthFailure(AppLocalizations l10n, AuthFailureCode? failure) =>
    switch (failure) {
      AuthFailureCode.invalidCredentials => l10n.authInvalidCredentials,
      AuthFailureCode.emailAlreadyRegistered => l10n.authEmailExists,
      AuthFailureCode.weakPassword => l10n.authWeakPassword,
      AuthFailureCode.invalidConfirmationCode => l10n.authInvalidCode,
      AuthFailureCode.expiredConfirmationCode => l10n.authExpiredCode,
      AuthFailureCode.userNotConfirmed => l10n.authUserNotConfirmed,
      AuthFailureCode.alreadyConfirmed => l10n.authAlreadyConfirmed,
      AuthFailureCode.network => l10n.authNetwork,
      AuthFailureCode.rateLimited => l10n.authRateLimited,
      AuthFailureCode.invalidInput => l10n.authInvalidInput,
      AuthFailureCode.unexpected || null => l10n.authenticationFailed,
    };
