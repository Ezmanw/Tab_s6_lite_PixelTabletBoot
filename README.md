# Pixel Tablet boot animation for the Galaxy Tab S6 Lite

A KernelSU module that replaces the Samsung boot animation with a
Pixel-Tablet-style landscape one: four Google-coloured dots fly in, swirl into
a ring, and orbit until Android finishes booting.

Rendered at **2000x1200**, the Tab S6 Lite's native panel resolution, on a
black background. A white version is one flag away — see
[Regenerating](#regenerating-the-animation).

![preview](docs/preview.gif)

105 frames: a 45-frame intro that plays once, then a 60-frame loop that
repeats until Android is ready.

| | |
|---|---|
| Package | `dist/PixelTabletBoot-v1.3.0.zip` (1.8 MB) |
| Tested root managers | KernelSU (Magisk and APatch use the same module format) |
| Android | 8.0+ |

## Read this first: boot logo vs. boot animation

These are two different screens, and only one of them is reachable from root:

**The Samsung logo** — the very first thing on screen, with "Powered by
Android" underneath. It lives in the `up_param` partition and is drawn by the
bootloader, before Linux userspace exists. **No KernelSU module can change
it.** Changing it means flashing a modified `up_param.bin` with Odin or
Heimdall, which requires an unlocked bootloader and trips Knox permanently.

**The boot animation** — what plays after that logo while Android boots. That
is a file on `/system`, so a module can replace it. That is what this repo
does.

If you specifically wanted the first screen changed, this module will not do
it, and there is no rooted way to do it.

## Install

1. Download `dist/PixelTabletBoot-v1.3.0.zip`.
2. KernelSU Manager → **Modules** → **Install from storage** → pick the zip.
3. Reboot.

The installer prints your panel size and how many Samsung animation files it
hid, so you can sanity-check before rebooting.

## ROM compatibility

| ROM | Works | Notes |
|---|---|---|
| AOSP-based (DerpFest, LineageOS, crDroid, ...) | Yes | Uses AOSP `bootanimation`, which reads `bootanimation.zip` natively. Nothing to work around. |
| Stock One UI | Probably | Needs Samsung's `bootanimation` to fall back to the zip once the `.qmg` files are hidden. Untested on hardware — see [black screen](#if-you-get-a-black-screen-while-booting). |

On an AOSP ROM the `.qmg` masking finds nothing and quietly does nothing; the
module just overrides whatever `bootanimation.zip` the ROM ships. The
installer prints which animation it found, so the log tells you which case
you are in.

## Why it also hides Samsung's `.qmg` files

One UI does not use AOSP's `bootanimation.zip`. Samsung's `bootanimation`
binary plays its own `bootsamsung.qmg` / `bootsamsungloop.qmg` and only falls
back to `bootanimation.zip` when those files are absent.

So dropping in a `bootanimation.zip` alone changes nothing. At install time
the module creates character-device `0:0` entries over any `.qmg` it finds —
the standard overlay trick for making a file vanish from the mounted view
without touching the real partition. Nothing on `/system` is modified.

`post-fs-data.sh` additionally bind-mounts the animation over
`/product/media/bootanimation.zip` and `/oem/media/bootanimation.zip` if those
exist, because `bootanimation` checks them before `/system/media`.

You can turn either behaviour off in `config.sh` before flashing.

## If the ROM's own animation still plays

`bootanimation` checks these paths and uses the **first** one that exists:

1. `/product/media/bootanimation.zip`
2. `/oem/media/bootanimation.zip`
3. `/system/media/bootanimation.zip`

Most AOSP ROMs ship theirs at `/product/media`, which outranks `/system/media`.
The module therefore overlays **both** paths, so its copy wins wherever the
ROM put one. (Up to v1.2.0 it only overlaid `/system/media` and relied on a
bind mount from `post-fs-data.sh` for `/product` — that runs as a script and
can lose the race against `bootanimation` starting.)

To see which copy is actually in place, run the diagnostic on the tablet as
root:

```
su -c sh /sdcard/diagnose.sh
```

It lists every path in priority order and marks which one is the module's, so
you can tell at a glance whether something is outranking it.

## If you get a black screen while booting

This only happens on stock One UI. The device still boots — only the
animation is missing. It means Samsung's `bootanimation` did not fall back to
the zip on your firmware.

Disable the module in KernelSU Manager and reboot, or set
`MASK_SAMSUNG_QMG=0` in the module's `config.sh` and reboot to get the
Samsung animation back. Nothing on `/system` was written, so removing the
module fully reverts it.

## Regenerating the animation

`tools/make_bootanimation.py` draws every frame; nothing is copied from a
Google device, so there is no proprietary asset here.

```bash
pip install Pillow
./build.sh --regen                      # defaults: dark, 2000x1200, 30fps
./build.sh --regen --theme light        # white background instead
./build.sh --regen --rotate 90          # if it renders sideways (see below)
./build.sh --regen --fps 60 --loop-seconds 1.5
```

Useful flags: `--theme` (`dark` or `light`) `--width` `--height` `--rotate`
`--fps` `--intro-seconds` `--loop-seconds` `--colors`.

### If the animation appears rotated

`bootanimation` draws to the panel's native framebuffer, which on some
tablets is portrait even though you hold the device in landscape. If the dots
come out sideways, rebuild with `--rotate 90` (or `270`) — this rotates the
rendered frames so the composition ends up the right way round on screen. The
generator writes the post-rotation dimensions into `desc.txt` for you.

## Layout

```
build.sh                        package dist/PixelTabletBoot-<version>.zip
tools/make_bootanimation.py     frame generator
tools/preview_gif.py            animated GIF preview of build/bootanim/
tools/diagnose.sh               on-device check of which animation wins
module/
  module.prop                   module metadata
  config.sh                     MASK_SAMSUNG_QMG, OVERRIDE_PRODUCT_OEM
  customize.sh                  install-time: hide .qmg, set permissions
  post-fs-data.sh               boot-time: cover /product and /oem paths
  system/media/bootanimation.zip
  system/product/media/bootanimation.zip   (generated by build.sh)
```

## Credits

The four-colour dot motif is Google's. The frames here are drawn from scratch
by the generator in `tools/`.
