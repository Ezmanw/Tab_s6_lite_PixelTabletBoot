#!/usr/bin/env bash
# Builds the flashable KernelSU module into dist/.
#   ./build.sh              package using the committed bootanimation.zip
#   ./build.sh --regen      regenerate the animation first
#   ./build.sh --regen --rotate 90 --width 2000 --height 1200
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
  echo ">> generating animation"
  python3 tools/make_bootanimation.py "${GEN_ARGS[@]}"
elif [ ${#GEN_ARGS[@]} -gt 0 ]; then
  echo "error: ${GEN_ARGS[*]} only applies with --regen" >&2
  exit 2
fi

[ -f module/system/media/bootanimation.zip ] || {
  echo "error: no animation; run ./build.sh --regen" >&2; exit 1; }

VERSION=$(sed -n 's/^version=//p' module/module.prop)
OUT="dist/PixelTabletBoot-${VERSION}.zip"

mkdir -p dist
rm -f "$OUT"
(cd module && zip -qr "../$OUT" . -x '.*' -x '*/.*')

echo ">> $OUT ($(du -h "$OUT" | cut -f1))"
