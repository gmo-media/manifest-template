#!/usr/bin/env bash

set -euxo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

PARTITIONS_DIR=/storage/partitions
POD_NAME="$HOSTNAME"
CUTOFF_DATE=$(date -d "7 days ago" +%Y%m%d)

cd "${PARTITIONS_DIR}"

printf "${CYAN}Archiving every partition older than or equal to: ${YELLOW}%s${NC}\n" "${CUTOFF_DATE}"

for dir in */ ; do
  # Skip if not a directory (e.g. no match for */)
  [ -d "${dir}" ] || continue

  partition=${dir%/} # strip trailing "/"

  # Accept only eight-digit names.
  case "${partition}" in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) ;;
    *) continue ;;
  esac

  # Skip anything newer than the cutoff.
  [ "${partition}" -gt "${CUTOFF_DATE}" ] && continue

  S3_OBJECT_KEY="archives/${partition}/${POD_NAME}.tar"
  S3_URL="s3://${BUCKET}/${S3_OBJECT_KEY}"

  # Check if the file already exists in S3
  found=$(aws s3api list-objects-v2 \
      --bucket "$BUCKET" \
      --prefix "$S3_OBJECT_KEY" \
      --max-items 1 \
      --query 'Contents[?Key==`'"$S3_OBJECT_KEY"'`].Key' \
      --output text)
  if [ "$found" != "None" ]; then
    printf "${YELLOW}→ Skipping %s${NC} - already archived at ${BLUE}%s${NC}\n" "${partition}" "${S3_URL}"
    continue
  fi

  printf "${CYAN}→ Archiving %s${NC}\n" "${partition}"

  # NOTE: No need to compress with gzip, since most files are already compressed efficiently
  tar -cf - "${partition}" | aws s3 cp - "${S3_URL}" --expected-size "$((5*1024*1024*1024))"

  printf "  ${GREEN}✓ Successfully archived %s${NC}\n" "${partition}"
done
