# Pixel Tablet boot animation for the Galaxy Tab S6 Lite

A KernelSU module that replaces the Samsung boot animation with a
Pixel-Tablet-style landscape one: four Google-coloured dots fly in, swirl into
a ring, and orbit until Android finishes booting.

Rendered at **2000x1200**, the Tab S6 Lite's native panel resolution, on a
black background. A white version is one flag away — see
[Regenerating](#regenerating-the-animation).

Two styles are built in, chosen with the volume keys while it installs —
plus the real Google animation if you supply it yourself
([how](#using-the-real-google-animation)):

| Volume UP — Google dots | Volume DOWN — Gemini spark |
|---|---|
| ![dots](docs/preview.gif) | ![spark](docs/preview-spark.gif) |

Each is 105 frames: a 45-frame intro that plays once, then a 60-frame loop
that repeats until Android is ready.

The spark is a Gemini-style mark drawn from scratch, not Google's own boot
animation — there is no canonical "Gemini boot animation" to copy.

| | |
|---|---|
| Package | `dist/PixelTabletBoot-v2.1.0.zip` (1.7 MB) |
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

1. Download `dist/PixelTabletBoot-v2.1.0.zip`.
2. KernelSU Manager → **Modules** → **Install from storage** → pick the zip.
3. Answer the prompts with the volume keys. If you have supplied your own
   animation (see below) you are asked about that first; otherwise you go
   straight to the built-in styles. Each prompt waits 20 seconds and falls
   back to the dots if nothing is pressed.
4. Reboot.

To skip the prompts, set `STYLE` to `official`, `dots` or `spark` in
`config.sh` before flashing.

## Using the real Google animation

**This module ships no Google artwork.** The Pixel Tablet's own boot
animation is a proprietary asset from Google's firmware and cannot be
redistributed here — so the module reads one you supply instead.

Put the file at any of these paths and reinstall the module; it is offered
on **Volume Up**:

```
/sdcard/PixelTabletBoot/official.zip
/sdcard/PixelTabletBoot/bootanimation.zip
/sdcard/Download/bootanimation.zip
```

The file is checked for a zip signature, so a wrong or partial download is
ignored rather than installed. Add more locations via `OFFICIAL_PATHS` in
`config.sh`.

### Getting it out of a factory image

The Pixel Tablet is codename **`tangorpro`**. Its factory images are public
at <https://developers.google.com/android/images>. The animation lives at
`/product/media/bootanimation.zip` inside `product.img`:

```bash
unzip tangorpro-*.zip                  # -> image-tangorpro-*.zip
unzip image-tangorpro-*.zip product.img
fsck.erofs --extract=out product.img   # recent images are EROFS
cp out/media/bootanimation.zip official.zip
```

Older images use a sparse ext4 `product.img`, which needs `simg2img` and a
loopback mount instead. Either way you are extracting from firmware you
downloaded yourself, for your own device.

**One caveat worth knowing:** the Pixel Tablet's panel is 2560x1600 (16:10)
and the Tab S6 Lite's is 2000x1200 (5:3). Those aspect ratios are close but
not identical, so the real animation will be very slightly stretched. The
built-in styles are drawn for your panel and are not.

### Why the animation might look stretched

The frames are drawn for 2000x1200. If your ROM reports a different
framebuffer, `bootanimation` scales them to fit, which makes everything
larger and distorted. The quickest check: **are the dots circles or ovals?**
Ovals mean the aspect ratio is wrong — rebuild with your real panel size:

```bash
./build.sh --regen --width W --height H
```

The installer prints your panel size and warns if it is not 2000x1200.

Orientation, on the other hand, is not something you can see here: both
styles are rotationally symmetric, so they look identical in portrait and
landscape. Only stretching is visible.

### Making it smaller

`--scale` sets how much of the screen the artwork covers (default `0.8`):

```bash
./build.sh --regen --scale 0.55     # noticeably smaller
```

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

To see which copy is actually in place, just look at the module in KernelSU
Manager after a reboot. `service.sh` rewrites its own description to one of:

- `[ Active - playing from /product/media/bootanimation.zip ]`
- `[ Overridden - the ROM's own file at <path> wins ]`
- `[ ? no bootanimation.zip found anywhere ]`

A full report lands at `/sdcard/pixeltabletboot.log`. No shell needed for
either. If you do want to run the check by hand, the same script ships inside
the module:

```
su -c sh /data/adb/modules/pixeltabletboot/diagnose.sh
```

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
  config.sh                     STYLE, OFFICIAL_PATHS, MASK_SAMSUNG_QMG, ...
  variants/dots.zip             the two animations; customize.sh picks one
  variants/spark.zip
  customize.sh                  install-time: hide .qmg, set permissions
  post-fs-data.sh               boot-time: cover /product and /oem paths
  service.sh                    boot-time: report status into the description
  system/media/bootanimation.zip           (staged at install time)
  system/product/media/bootanimation.zip   (staged at install time)
```

## Credits

The four-colour dot motif is Google's. The frames here are drawn from scratch
by the generator in `tools/`.
