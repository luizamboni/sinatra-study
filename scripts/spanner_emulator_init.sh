#!/usr/bin/env bash
set -euo pipefail

SPANNER_PROJECT_ID=${SPANNER_PROJECT_ID:-local-project}
SPANNER_INSTANCE_ID=${SPANNER_INSTANCE_ID:-local-instance}
SPANNER_DATABASE_ID=${SPANNER_DATABASE_ID:-local-db}
SPANNER_EMULATOR_REST_HOST=${SPANNER_EMULATOR_REST_HOST:-spanner:9020}

export CLOUDSDK_CORE_DISABLE_PROMPTS=1

gcloud config set auth/disable_credentials true
gcloud config set project "$SPANNER_PROJECT_ID"
gcloud config set api_endpoint_overrides/spanner "http://${SPANNER_EMULATOR_REST_HOST}/"

for _ in $(seq 1 30); do
  if gcloud spanner instances list >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! gcloud spanner instances describe "$SPANNER_INSTANCE_ID" >/dev/null 2>&1; then
  gcloud spanner instances create "$SPANNER_INSTANCE_ID" \
    --config=emulator-config \
    --description="Local Spanner Emulator" \
    --nodes=1
fi

if ! gcloud spanner databases describe "$SPANNER_DATABASE_ID" --instance="$SPANNER_INSTANCE_ID" >/dev/null 2>&1; then
  gcloud spanner databases create "$SPANNER_DATABASE_ID" --instance="$SPANNER_INSTANCE_ID"
fi
