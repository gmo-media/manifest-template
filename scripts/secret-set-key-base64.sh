#!/usr/bin/env bash

if [ "$#" -ne 3 ]; then
  echo >&2 "Add a key to encrypted sops file."
  echo >&2 "Use this if you need to set values that contains special characters (e.g. \"'\`#~)."
  echo >&2 "Usage:   $0 filename key data"
  echo >&2 "Example: $0 dev/karpenter/secrets/env.yaml MY_ENV_NAME '123><$;*'"
  exit 1
fi

set -euo pipefail

encoded=$(echo -n "$3" | base64)

echo "Setting the following value: make sure that no special characters are escaped / changed with shell expansions."
echo "$encoded" | base64 -d | hexdump -C

set -x
sops --config .sops.yaml set "$1" "[\"data\"][\"$2\"]" "\"$encoded\""
