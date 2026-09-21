#!/system/bin/sh
# Run as root ON THE TABLET to see which boot animation the system will use:
#   su -c sh /sdcard/diagnose.sh
#
# Prints every path bootanimation checks, in priority order, and whether the
# module's copy is the one sitting there.

MODID=pixeltabletboot
echo "=== module ==="
for BASE in /data/adb/modules /data/adb/ksu/modules; do
  [ -d "$BASE/$MODID" ] || continue
  echo "installed at $BASE/$MODID"
  sed -n 's/^version=/  version: /p' "$BASE/$MODID/module.prop" 2>/dev/null
  [ -f "$BASE/$MODID/disable" ] && echo "  STATUS: DISABLED" || echo "  STATUS: enabled"
  [ -f "$BASE/$MODID/remove" ] && echo "  STATUS: pending removal"
done
[ -d /data/adb/modules/$MODID ] || [ -d /data/adb/ksu/modules/$MODID ] || \
  echo "NOT INSTALLED"

echo
echo "=== bootanimation paths, highest priority first ==="
OURS=""
for BASE in /data/adb/modules /data/adb/ksu/modules; do
  [ -f "$BASE/$MODID/system/media/bootanimation.zip" ] && \
    OURS="$BASE/$MODID/system/media/bootanimation.zip"
done
[ -n "$OURS" ] && OURSUM=$(md5sum "$OURS" | cut -d' ' -f1) || OURSUM="?"
echo "module copy md5: $OURSUM"
echo
for P in /product/media/bootanimation.zip \
         /system/product/media/bootanimation.zip \
         /oem/media/bootanimation.zip \
         /system/media/bootanimation.zip; do
  if [ -f "$P" ]; then
    SUM=$(md5sum "$P" | cut -d' ' -f1)
    if [ "$SUM" = "$OURSUM" ]; then
      echo "  $P  <-- OURS"
    else
      echo "  $P  <-- ROM's (md5 $SUM)"
    fi
  else
    echo "  $P  (absent)"
  fi
done

echo
echo "=== the first 'OURS' above is what plays; if a ROM's copy is listed"
echo "=== above it, that one wins instead"
echo
echo "=== what the ROM is configured to use ==="
getprop | grep -i bootanim
echo
echo "=== samsung .qmg (stock One UI only) ==="
ls -l /system/media/*.qmg /product/media/*.qmg 2>/dev/null || echo "  none"
