#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-6.17.7}"
MAJOR="${VERSION%%.*}"
ARCHIVE="linux-${VERSION}.tar.xz"
BASE="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x"
URL="${BASE}/${ARCHIVE}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: $0 [kernel-version, e.g. 6.17.7]" >&2
  exit 2
fi

if [[ ! -f "$ARCHIVE" ]]; then
  curl --fail --location --retry 3 --output "$ARCHIVE" "$URL"
fi
CHECKSUMS="sha256sums.asc"
if [[ ! -f "$CHECKSUMS" ]]; then
  curl --fail --location --retry 3 --output "$CHECKSUMS" "${BASE}/${CHECKSUMS}"
fi

EXPECTED="$(awk -v file="$ARCHIVE" '$2 == file {print $1; exit}' "$CHECKSUMS")"
if [[ ! "$EXPECTED" =~ ^[[:xdigit:]]{64}$ ]]; then
  echo "No SHA-256 entry found for ${ARCHIVE} in ${CHECKSUMS}" >&2
  exit 1
fi
printf '%s  %s\n' "$EXPECTED" "$ARCHIVE" | sha256sum --check --status
echo "SHA-256 verified: ${ARCHIVE}"

if [[ ! -d "linux-${VERSION}" ]]; then
  tar -xJf "$ARCHIVE"
fi
ln -sfn "linux-${VERSION}" linux
printf 'Linux %s is ready at %s/linux\n' "$VERSION" "$PWD"
