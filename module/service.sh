#!/system/bin/sh
# late_start service: works out which boot animation actually won, writes a
# full report to the log, and rewrites this module's description so the answer
# is visible in KernelSU Manager without a shell.

MODDIR=${0%/*}
PROP="$MODDIR/module.prop"
LOG=/data/adb/pixeltabletboot.log
BASE="Pixel-Tablet-style landscape boot animation. Hides Samsung's .qmg, which otherwise takes priority over bootanimation.zip."

# Which style was chosen at install time, for the status line.
STYLE=$(sed -n 's/^installed_style=//p' "$MODDIR/style" 2>/dev/null)
[ -n "$STYLE" ] && BASE="Style: $STYLE. $BASE"

# Wait for /data to settle before writing anything.
for i in 1 2 3 4 5 6 7 8 9 10; do
  [ -d /data/adb ] && break
  sleep 2
done

OURS="$MODDIR/system/media/bootanimation.zip"
if [ -f "$OURS" ]; then
  OURSUM=$(md5sum "$OURS" 2>/dev/null | cut -d' ' -f1)
else
  OURSUM=""
fi

# The first existing path is the one bootanimation uses.
WINNER=""
WINSUM=""
for P in /product/media/bootanimation.zip \
         /system/product/media/bootanimation.zip \
         /oem/media/bootanimation.zip \
         /system/media/bootanimation.zip; do
  if [ -f "$P" ]; then
    WINNER="$P"
    WINSUM=$(md5sum "$P" 2>/dev/null | cut -d' ' -f1)
    break
  fi
done

if [ -z "$WINNER" ]; then
  STATUS="[ ? no bootanimation.zip found anywhere ]"
elif [ -z "$OURSUM" ]; then
  STATUS="[ ! module animation missing ]"
elif [ "$WINSUM" = "$OURSUM" ]; then
  STATUS="[ Active - playing from $WINNER ]"
else
  STATUS="[ Overridden - the ROM's own file at $WINNER wins ]"
fi

{
  echo "Pixel Tablet boot animation - $(date)"
  echo
  echo "module copy md5 : ${OURSUM:-none}"
  echo "winning path    : ${WINNER:-none}"
  echo "winning md5     : ${WINSUM:-none}"
  echo "verdict         : $STATUS"
  echo
  echo "all paths, highest priority first:"
  for P in /product/media/bootanimation.zip \
           /system/product/media/bootanimation.zip \
           /oem/media/bootanimation.zip \
           /system/media/bootanimation.zip; do
    if [ -f "$P" ]; then
      S=$(md5sum "$P" 2>/dev/null | cut -d' ' -f1)
      [ "$S" = "$OURSUM" ] && echo "  $P  <-- OURS" || echo "  $P  <-- ROM's ($S)"
    else
      echo "  $P  (absent)"
    fi
  done
  echo
  echo "bootanim props:"
  getprop | grep -i bootanim
  echo
  echo "samsung .qmg:"
  ls -l /system/media/*.qmg /product/media/*.qmg 2>/dev/null || echo "  none"
} > "$LOG" 2>&1

# Mirror somewhere a file manager can reach, best effort.
cp -f "$LOG" /sdcard/pixeltabletboot.log 2>/dev/null

# Rewrite the description in place so KernelSU Manager shows the verdict.
if [ -w "$PROP" ]; then
  TMP="$MODDIR/.prop.tmp"
  grep -v '^description=' "$PROP" > "$TMP" 2>/dev/null
  echo "description=$STATUS $BASE" >> "$TMP"
  mv -f "$TMP" "$PROP"
fi

exit 0
