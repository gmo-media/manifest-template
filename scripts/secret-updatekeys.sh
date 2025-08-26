#!/usr/bin/env bash

if [ "$#" -ne 1 ]; then
  echo >&2 "Update keys for encrypted sops file according to .sops.yaml. Requires private key."
  echo >&2 "Usage: $0 filename"
  exit 1
fi

sops updatekeys "$1"
