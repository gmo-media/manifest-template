#!/usr/bin/env bash

if [ "$#" -ne 1 ]; then
  echo >&2 "Sort keys under stringData in encrypted sops file. Requires private key."
  echo >&2 "Usage:   $0 filename"
  echo >&2 "Example: $0 dev/karpenter/secrets/env.yaml"
  exit 1
fi

set -euxo pipefail

TMP_FILE=$(mktemp)
trap 'rm $TMP_FILE' EXIT

sops --config .sops.yaml decrypt "$1" | \
  yq eval '.stringData |= sort_keys(..)' | \
  sops --config .sops.yaml encrypt /dev/stdin --input-type yaml --output-type yaml > "$TMP_FILE"
cp "$TMP_FILE" "$1"
