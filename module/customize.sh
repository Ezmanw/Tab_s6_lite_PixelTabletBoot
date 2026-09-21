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

# Report the panel size so a mismatch is obvious before the first reboot.
# bootanimation scales frames to fit, so a mismatch is cosmetic, not fatal.
FB=$(getprop ro.surface_flinger.primary_display_orientation)
SIZE=$(wm size 2>/dev/null | sed -n 's/^Physical size: //p')
if [ -n "$SIZE" ]; then
  ui_print "- Panel: $SIZE (animation drawn for 2000x1200)"
  case "$SIZE" in
    2000x1200|1200x2000) ;;
    *) ui_print "! Panel differs: bootanimation will scale the frames to"
       ui_print "  fit, which stretches them.  Rebuild with"
       ui_print "  ./build.sh --regen --width W --height H" ;;
  esac
fi
[ -n "$FB" ] && ui_print "- Display orientation: $FB"

# --- pick a style -----------------------------------------------------
# getevent blocks until a key is pressed, so it is bounded by `timeout`.
# Without a timeout binary there is no safe way to wait, so we take the
# default rather than risk hanging the installer forever.
# 0 = got a volume key, 1 = some other event (keep waiting), 2 = cannot wait.
read_volume_key() {
  command -v timeout >/dev/null 2>&1 || return 2
  OUT=$(timeout "$1" getevent -lqc 1 2>/dev/null)
  [ -z "$OUT" ] && return 2
  KEY=$(echo "$OUT" | grep -o 'KEY_VOLUMEUP\|KEY_VOLUMEDOWN' | head -1)
  [ -n "$KEY" ] && return 0
  return 1
}

case "$STYLE" in
  dots|spark)
    ui_print "- Style: $STYLE (set in config.sh)"
    ;;
  *)
    ui_print " "
    ui_print "  Choose your boot animation:"
    ui_print " "
    ui_print "    VOLUME UP   = Google dots (classic Pixel Tablet)"
    ui_print "    VOLUME DOWN = Gemini spark"
    ui_print " "
    ui_print "  Waiting ${KEY_TIMEOUT}s..."
    STYLE=""
    TRIES=0
    # A touch or any other input returns an event too, so ignore those and
    # keep waiting rather than giving up on the first one.
    while [ -z "$STYLE" ] && [ "$TRIES" -lt 16 ]; do
      read_volume_key "$KEY_TIMEOUT"
      case "$?" in
        0) case "$KEY" in
             KEY_VOLUMEUP)   STYLE=dots ;;
             KEY_VOLUMEDOWN) STYLE=spark ;;
           esac ;;
        2) break ;;
      esac
      TRIES=$((TRIES + 1))
    done
    if [ -z "$STYLE" ]; then
      STYLE="$DEFAULT_STYLE"
      ui_print "- No key detected, using default: $STYLE"
      ui_print "  (set STYLE=dots or STYLE=spark in config.sh to skip this)"
    else
      [ "$STYLE" = dots ] && ui_print "- Volume UP: Google dots" \
                          || ui_print "- Volume DOWN: Gemini spark"
    fi
    ;;
esac

VARIANT="$MODPATH/variants/$STYLE.zip"
[ -f "$VARIANT" ] || abort "! variant $STYLE missing from the package"

# bootanimation reads /product/media before /system/media, so install to both
# and let the overlay cover whichever one the ROM uses.
for DEST in "$MODPATH/system/media" "$MODPATH/system/product/media"; do
  mkdir -p "$DEST"
  cp -f "$VARIANT" "$DEST/bootanimation.zip" || abort "! could not stage $DEST"
done
rm -rf "$MODPATH/variants"
echo "installed_style=$STYLE" > "$MODPATH/style"
ui_print "- Installed $STYLE animation ($(du -h "$MODPATH/system/media/bootanimation.zip" | cut -f1))"

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
for F in "$MODPATH/system/media/bootanimation.zip" \
         "$MODPATH/system/product/media/bootanimation.zip"; do
  [ -f "$F" ] && set_perm "$F" 0 0 0644 u:object_r:system_file:s0
done

ui_print " "
ui_print "- After rebooting, this module's description in KernelSU"
ui_print "  Manager shows whether the animation actually won."
ui_print "  Full report: /sdcard/pixeltabletboot.log"
ui_print " "
ui_print "- Done.  Reboot to see it."
ui_print "  Black screen at boot?  Disable the module in KernelSU"
ui_print "  Manager and reboot; see the README for details."
ui_print " "
