#!/system/bin/sh
# Nothing to undo: every change this module makes is an overlay or a bind
# mount inside the module's own mount namespace, and both disappear when the
# module is removed and the device reboots.
exit 0
