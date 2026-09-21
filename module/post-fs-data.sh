#!/system/bin/sh
# Runs at the post-fs-data trigger, which is before surfaceflinger starts
# bootanimation, so bind mounts made here are in place in time.

MODDIR=${0%/*}
. "$MODDIR/config.sh" 2>/dev/null

ANIM="$MODDIR/system/media/bootanimation.zip"
[ -f "$ANIM" ] || exit 0

# bootanimation looks in /product and /oem before /system, so the module's
# overlay of /system/media alone is not always enough.  Bind over any
# higher-priority copy that actually exists.
if [ "$OVERRIDE_PRODUCT_OEM" != "0" ]; then
  for TARGET in /product/media/bootanimation.zip \
                /system/product/media/bootanimation.zip \
                /oem/media/bootanimation.zip; do
    [ -f "$TARGET" ] && mount -o bind "$ANIM" "$TARGET"
  done
fi

exit 0
