#!/usr/bin/env bash
# FL-023 / MON-01 / REL-06: approved private iOS QA candidate against AWS DEV.
set -euo pipefail

cd "$(dirname "$0")/.."
exec flutter build ipa --release --no-pub   --build-name=1.0.0 --build-number=5 --export-method=app-store   --dart-define=FOLOO_ENVIRONMENT=dev   --dart-define=FOLOO_ALLOW_DEV_RELEASE=true   --dart-define=FOLOO_UNLIMITED_QA_MODE=true   --dart-define=FOLOO_APPLE_SIGNIN=true   --dart-define=FOLOO_MICROSOFT_SIGNIN=false   --dart-define=FOLOO_ACCOUNT_DELETION_ENABLED=true   --dart-define=FOLOO_WEB_ACCOUNT_LINK=false   --dart-define=FOLOO_OCR_QA_DIAGNOSTICS=false
