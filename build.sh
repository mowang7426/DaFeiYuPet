#!/bin/sh
set -eu
cd "$(dirname "$0")"
scheme="${1:-rootless}"
case "$scheme" in
  rootless) THEOS="${THEOS_ROOTLESS:-${THEOS:-}}" ;;
  roothide) THEOS="${THEOS_ROOTHIDE:-${THEOS:-}}" ;;
  *) echo 'Use rootless or roothide; build in independent toolchains' >&2; exit 2 ;;
esac
export THEOS
: "${THEOS:?Set THEOS_ROOTLESS/THEOS_ROOTHIDE or THEOS}"
test -d "$THEOS/sdks/iPhoneOS16.5.sdk"
if [ "$scheme" = roothide ]; then
  test -f "$THEOS/vendor/include/roothide.h" || test -f "$THEOS/include/roothide.h" || { echo 'Missing genuine RootHide headers' >&2; exit 2; }
fi
make clean THEOS_PACKAGE_SCHEME="$scheme"
make package THEOS_PACKAGE_SCHEME="$scheme" FINALPACKAGE=1 DEBUG=0
