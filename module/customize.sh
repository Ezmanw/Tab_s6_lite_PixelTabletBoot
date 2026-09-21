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
# getevent blocks until an input event arrives, so the wait has to be bounded.
# `timeout` is used when present; otherwise getevent is backgrounded and
# killed, which needs no extra binaries.
#
# 0 = got a volume key, 1 = some other event (keep waiting), 2 = cannot wait.
GETEVENT=$(command -v getevent 2>/dev/null || echo /system/bin/getevent)

read_volume_key() {
  OUT=""
  EVTMP="${TMPDIR:-/data/local/tmp}/pxtb.ev.$$"
  rm -f "$EVTMP"

  if command -v timeout >/dev/null 2>&1; then
    timeout "$1" "$GETEVENT" -lqc 1 > "$EVTMP" 2>/dev/null
  else
    # No timeout binary: run getevent in the background and kill it once the
    # wait is up, polling for it to finish in the meantime.
    "$GETEVENT" -lqc 1 > "$EVTMP" 2>/dev/null &
    GPID=$!
    I=0
    while [ "$I" -lt "$1" ]; do
      kill -0 "$GPID" 2>/dev/null || break
      sleep 1
      I=$((I + 1))
    done
    kill "$GPID" 2>/dev/null
    wait "$GPID" 2>/dev/null
  fi

  OUT=$(cat "$EVTMP" 2>/dev/null)
  rm -f "$EVTMP"
  [ -z "$OUT" ] && return 2
  KEY=$(echo "$OUT" | grep -o 'KEY_VOLUMEUP\|KEY_VOLUMEDOWN' | head -1)
  [ -n "$KEY" ] && return 0
  return 1
}

# Offers two choices and sets PICK to up, down, or "" if neither arrived.
# A touch returns an event too, so non-volume input is ignored rather than
# treated as an answer or as a reason to give up.
ask_keys() {
  ui_print " "
  ui_print "    VOLUME UP   = $1"
  ui_print "    VOLUME DOWN = $2"
  ui_print " "
  ui_print "  Waiting ${KEY_TIMEOUT}s..."
  PICK=""
  TRIES=0
  while [ -z "$PICK" ] && [ "$TRIES" -lt 16 ]; do
    read_volume_key "$KEY_TIMEOUT"
    case "$?" in
      0) case "$KEY" in
           KEY_VOLUMEUP)   PICK=up ;;
           KEY_VOLUMEDOWN) PICK=down ;;
         esac ;;
      2) break ;;
    esac
    TRIES=$((TRIES + 1))
  done
}

# A style written to a file is the most reliable route: no input handling,
# and it can be edited with any file manager.
FILE_STYLE=""
for F in $STYLE_FILES; do
  [ -f "$F" ] || continue
  FILE_STYLE=$(tr -d ' \t\r\n' < "$F" 2>/dev/null | tr 'A-Z' 'a-z')
  [ -n "$FILE_STYLE" ] && { ui_print "- Style from $F: $FILE_STYLE"; break; }
done
case "$FILE_STYLE" in
  official|dots|spark) STYLE="$FILE_STYLE" ;;
  "") ;;
  *)  ui_print "! $FILE_STYLE is not a valid style, ignoring" ;;
esac

# An animation the user supplied themselves, e.g. one pulled from a Pixel
# Tablet factory image.  Checked for a zip magic number, not just existence.
OFFICIAL=""
for P in $OFFICIAL_PATHS; do
  if [ -f "$P" ] && [ "$(head -c 2 "$P" 2>/dev/null)" = "PK" ]; then
    OFFICIAL="$P"
    break
  fi
done

case "$STYLE" in
  official)
    [ -n "$OFFICIAL" ] || abort "! STYLE=official but no animation found in: $OFFICIAL_PATHS"
    ui_print "- Style: official (set in config.sh)"
    ;;
  dots|spark)
    ui_print "- Style: $STYLE (set in config.sh)"
    ;;
  *)
    STYLE=""
    ASK_BUILTIN=1     # whether to run the dots-vs-spark prompt

    if [ -n "$OFFICIAL" ]; then
      ui_print " "
      ui_print "  Found your own animation:"
      ui_print "    $OFFICIAL"
      ask_keys "that animation" "the built-in styles"
      case "$PICK" in
        up)   STYLE=official; ASK_BUILTIN=0 ;;
        down) ;;                       # fall through to the built-in prompt
        *)    ASK_BUILTIN=0 ;;         # no key at all: do not ask again
      esac
    else
      ui_print " "
      ui_print "  No user-supplied animation found.  To use the official"
      ui_print "  Google one, put its bootanimation.zip at:"
      ui_print "    /sdcard/PixelTabletBoot/official.zip"
      ui_print "  and install this module again (see the README)."
    fi

    if [ -z "$STYLE" ] && [ "$ASK_BUILTIN" = 1 ]; then
      ask_keys "Google dots (classic)" "Gemini spark"
      case "$PICK" in
        up)   STYLE=dots ;;
        down) STYLE=spark ;;
      esac
    fi

    if [ -z "$STYLE" ]; then
      STYLE="$DEFAULT_STYLE"
      ui_print "- No volume key detected, using default: $STYLE"
      [ -x "$GETEVENT" ] || ui_print "  reason: no getevent at $GETEVENT"
      command -v timeout >/dev/null 2>&1 || \
        ui_print "  reason: no timeout binary (used the fallback wait)"
      ui_print "  To choose without the volume keys, write dots, spark or"
      ui_print "  official into /sdcard/PixelTabletBoot/style.txt and"
      ui_print "  install this module again."
    else
      ui_print "- Chose: $STYLE"
    fi
    ;;
esac

if [ "$STYLE" = official ]; then
  SRC="$OFFICIAL"
else
  SRC="$MODPATH/variants/$STYLE.zip"
fi
[ -f "$SRC" ] || abort "! animation $STYLE missing"

# bootanimation reads /product/media before /system/media, so install to both
# and let the overlay cover whichever one the ROM uses.
for DEST in "$MODPATH/system/media" "$MODPATH/system/product/media"; do
  mkdir -p "$DEST"
  cp -f "$SRC" "$DEST/bootanimation.zip" || abort "! could not stage $DEST"
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
