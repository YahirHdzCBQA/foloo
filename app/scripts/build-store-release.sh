#!/usr/bin/env bash
# REL-06 / REL-07: the store build entry point accepts only public PROD settings.
set -euo pipefail

if [[ $# != 1 || ( "$1" != ios && "$1" != android ) ]]; then
  echo 'Usage: bash app/scripts/build-store-release.sh ios|android' >&2
  exit 2
fi

if [[ ! "${FOLOO_STORE_BUILD_NUMBER:-}" =~ ^[1-9][0-9]*$ ]]; then
  echo 'Set FOLOO_STORE_BUILD_NUMBER to the next available store build number' >&2
  exit 2
fi
build_number="--build-number=$FOLOO_STORE_BUILD_NUMBER"

keys=(
  FOLOO_AWS_REGION
  FOLOO_COGNITO_USER_POOL_ID
  FOLOO_COGNITO_APP_CLIENT_ID
  FOLOO_COGNITO_HOSTED_UI_DOMAIN
  FOLOO_API_BASE_URL
)
defines=(--dart-define=FOLOO_ENVIRONMENT=prod --dart-define=FOLOO_ACCOUNT_DELETION_ENABLED=true)
for key in "${keys[@]}"; do
  if [[ -z "${!key:-}" ]]; then
    echo "Missing PROD output: $key" >&2
    exit 2
  fi
  defines+=("--dart-define=$key=${!key}")
done

if [[ "$FOLOO_AWS_REGION" != us-east-1 ||
      ! "$FOLOO_COGNITO_USER_POOL_ID" =~ ^us-east-1_[[:alnum:]]+$ ||
      ! "$FOLOO_COGNITO_APP_CLIENT_ID" =~ ^[a-z0-9]{20,128}$ ||
      ! "$FOLOO_COGNITO_HOSTED_UI_DOMAIN" =~ ^[a-z0-9-]+\.auth\.us-east-1\.amazoncognito\.com$ ||
      ! "$FOLOO_API_BASE_URL" =~ ^https://[a-z0-9.-]+/?$ ]]; then
  echo 'Invalid PROD identifiers or API origin' >&2
  exit 2
fi
if [[ "$FOLOO_COGNITO_USER_POOL_ID" == us-east-1_QVm3dWe4O ||
      "$FOLOO_COGNITO_APP_CLIENT_ID" == 6jong3atp2crqcsde6g215ant8 ||
      "$FOLOO_COGNITO_HOSTED_UI_DOMAIN" == us-east-1qvm3dwe4o.auth.us-east-1.amazoncognito.com ||
      "${FOLOO_API_BASE_URL%/}" == https://zbc91cpy10.execute-api.us-east-1.amazonaws.com ]]; then
  echo 'Store builds require independent PROD outputs' >&2
  exit 2
fi

cd "$(dirname "$0")/.."
if [[ "$1" == ios ]]; then
  if [[ "${FOLOO_APPLE_SIGNIN:-}" != true ]]; then
    echo 'iOS with Google requires verified Apple Sign-In (D-21)' >&2
    exit 2
  fi
  exec flutter build ipa --release "$build_number" "${defines[@]}" --dart-define=FOLOO_APPLE_SIGNIN=true
fi

case "${FOLOO_ANDROID_DISABLE_R8_FOR_OCR_QA:-}" in
  [Tt][Rr][Uu][Ee])
    echo 'The Android R8 QA override is forbidden in a store build' >&2
    exit 2
    ;;
esac
exec flutter build appbundle --release "$build_number" "${defines[@]}"
