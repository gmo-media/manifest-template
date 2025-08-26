#!/usr/bin/env bash

if [ "$#" -ne 2 ]; then
  echo >&2 "Deletes a key from encrypted sops file."
  echo >&2 "Usage:   $0 filename key"
  echo >&2 "Example: $0 dev/karpenter/secrets/env.yaml MY_ENV_NAME"
  exit 1
fi

set -eux

sops --config .sops.yaml unset "$1" "[\"stringData\"][\"$2\"]"
