#!/usr/bin/env bash

if [ "$#" -ne 1 ]; then
  echo >&2 "Edit a sops encrypted secret. Requires private key."
  echo >&2 "Usage: $0 filename"
  exit 1
fi

sops --config .sops.yaml --in-place "$1"
