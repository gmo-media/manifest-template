#!/usr/bin/env bash

if [ "$#" -ne 1 ]; then
  echo >&2 "Encrypt a file with sops."
  echo >&2 "Usage: $0 filename"
  exit 1
fi

sops --encrypt --config .sops.yaml --in-place "$1"
