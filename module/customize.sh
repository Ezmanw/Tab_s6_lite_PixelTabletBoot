#!/system/bin/sh
# Installed by KernelSU / Magisk.  $MODPATH is the unpacked module directory.

SKIPUNZIP=0

ui_print " "
ui_print "  Pixel Tablet boot animation"
ui_print "  for Galaxy Tab S6 Lite"
ui_print " "

if [ "$KSU" = "true" ]; then
  ui_print "- KernelSU $KSU_VER ($KSU_VER_CODE)"
elif [ "$APATCH" = "true" ]; then
  ui_print "- APatch"
elif [ -n "$MAGISK_VER" ]; then
  ui_print "- Magisk $MAGISK_VER"
else
  ui_print "! Unknown root manager, continuing anyway"
fi

if [ "$API" -lt 26 ]; then
  abort "! Android 8.0 or newer required"
fi

. "$MODPATH/config.sh"

ANIM="$MODPATH/system/media/bootanimation.zip"
[ -f "$ANIM" ] || abort "! bootanimation.zip missing from the package"
ui_print "- Animation: $(du -h "$ANIM" | cut -f1)"

# Report the panel size so a mismatch is obvious before the first reboot.
# bootanimation scales frames to fit, so a mismatch is cosmetic, not fatal.
FB=$(getprop ro.surface_flinger.primary_display_orientation)
SIZE=$(wm size 2>/dev/null | sed -n 's/^Physical size: //p')
[ -n "$SIZE" ] && ui_print "- Panel: $SIZE (animation is 2000x1200)"
[ -n "$FB" ] && ui_print "- Display orientation: $FB"

# Report which animation the ROM currently uses.  AOSP-based ROMs (DerpFest,
# LineageOS, ...) ship a plain bootanimation.zip and need no .qmg handling;
# One UI ships .qmg and ignores the zip until those are gone.
FOUND=""
for P in /product/media/bootanimation.zip /system/product/media/bootanimation.zip \
         /oem/media/bootanimation.zip /system/media/bootanimation.zip; do
  [ -f "$P" ] && FOUND="$FOUND $P"
done
if [ -n "$FOUND" ]; then
  for P in $FOUND; do ui_print "- ROM animation found: $P"; done
else
  ui_print "- ROM ships no bootanimation.zip"
fi

# Samsung's bootanimation prefers its own .qmg files and ignores
# bootanimation.zip while they exist.  A character device 0:0 in the module
# tree is the standard way to make a file disappear from the mounted view.
if [ "$MASK_SAMSUNG_QMG" = "1" ]; then
  MASKED=0
  for QMG in bootsamsung.qmg bootsamsungloop.qmg bootsamsungloop2.qmg \
             bootsamsung2.qmg; do
    for DIR in /system/media /system/product/media /product/media; do
      [ -f "$DIR/$QMG" ] || continue
      case "$DIR" in
        /system/media) REL="system/media" ;;
        *)             REL="system/product/media" ;;
      esac
      mkdir -p "$MODPATH/$REL"
      # Skip if an earlier iteration already masked this module-tree path.
      [ -e "$MODPATH/$REL/$QMG" ] && continue
      mknod "$MODPATH/$REL/$QMG" c 0 0 && MASKED=$((MASKED + 1))
    done
  done
  if [ "$MASKED" -gt 0 ]; then
    ui_print "- One UI detected: hid $MASKED Samsung .qmg file(s)"
  else
    ui_print "- No Samsung .qmg files (AOSP-style ROM, nothing to hide)"
  fi
else
  ui_print "! MASK_SAMSUNG_QMG=0: Samsung's animation will still win"
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/system/media/bootanimation.zip" 0 0 0644 u:object_r:system_file:s0
[ -f "$MODPATH/system/product/media/bootanimation.zip" ] && \
  set_perm "$MODPATH/system/product/media/bootanimation.zip" 0 0 0644 u:object_r:system_file:s0

ui_print " "
ui_print "- Done.  Reboot to see it."
ui_print "  Black screen at boot?  Disable the module in KernelSU"
ui_print "  Manager and reboot; see the README for details."
ui_print " "
