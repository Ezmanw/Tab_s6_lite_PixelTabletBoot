#!/usr/bin/env bash
# Builds the flashable KernelSU module into dist/.
#   ./build.sh              package using the committed animations
#   ./build.sh --regen      regenerate both styles first
#   ./build.sh --regen --scale 0.6 --rotate 90
set -euo pipefail

cd "$(dirname "$0")"

REGEN=0
GEN_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --regen) REGEN=1; shift ;;
    *)       GEN_ARGS+=("$1"); shift ;;
  esac
done

if [ "$REGEN" = 1 ]; then
  mkdir -p module/variants
  for STYLE in dots spark; do
    echo ">> generating $STYLE"
    # The spark's gradient needs a deeper palette than the flat dots do.
    EXTRA=()
    [ "$STYLE" = spark ] && EXTRA=(--colors 128)
    python3 tools/make_bootanimation.py --style "$STYLE" \
      "${EXTRA[@]}" "${GEN_ARGS[@]}" -o "module/variants/$STYLE.zip"
  done
elif [ ${#GEN_ARGS[@]} -gt 0 ]; then
  echo "error: ${GEN_ARGS[*]} only applies with --regen" >&2
  exit 2
fi

for STYLE in dots spark; do
  [ -f "module/variants/$STYLE.zip" ] || {
    echo "error: missing module/variants/$STYLE.zip; run ./build.sh --regen" >&2
    exit 1; }
done

# Ship the diagnostic inside the module so it can be run on-device without
# fetching anything else.
cp -f tools/diagnose.sh module/diagnose.sh

# customize.sh picks a variant at install time and copies it into place, so
# the package carries no system/ tree of its own.
rm -rf module/system

VERSION=$(sed -n 's/^version=//p' module/module.prop)
OUT="dist/PixelTabletBoot-${VERSION}.zip"

mkdir -p dist
rm -f "$OUT"
(cd module && zip -qr "../$OUT" . -x '.*' -x '*/.*')

echo ">> $OUT ($(du -h "$OUT" | cut -f1))"
