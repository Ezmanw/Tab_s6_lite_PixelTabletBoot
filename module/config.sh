# Settings for the Pixel Tablet boot animation module.
# Edit before flashing, or edit in place under the module directory and reboot.

# Which animation to install:
#   ask    prompt at install time with the volume keys (default)
#   dots   Google dots, the classic Pixel Tablet look
#   spark  the Gemini spark
STYLE=ask

# Used when STYLE=ask but no key is pressed, or when the device has no
# `timeout` binary to bound the wait.
DEFAULT_STYLE=dots

# How long to wait for a volume key, in seconds.
KEY_TIMEOUT=20

# Samsung's bootanimation plays /system/media/bootsamsung.qmg and only falls
# back to bootanimation.zip when those files are absent.  With this set to 1
# the module hides them so the chosen animation is used.
#
# Set to 0 if you would rather keep the Samsung animation (the module then
# installs the zip but nothing on a stock One UI ROM will play it).
MASK_SAMSUNG_QMG=1

# Also override the animation at the higher-priority /product and /oem paths,
# if the ROM ships one there.  Leave at 1 unless you are debugging.
OVERRIDE_PRODUCT_OEM=1
