#!/usr/bin/env bash

if [ "$#" -ne 3 ]; then
  echo >&2 "Add a key to encrypted sops file."
  echo >&2 "Usage:   $0 filename key data"
  echo >&2 "Example: $0 dev/karpenter/secrets/env.yaml MY_ENV_NAME \"my-env-value\""
  exit 1
fi

set -eux

sops --config .sops.yaml set "$1" "[\"stringData\"][\"$2\"]" "\"$3\""
