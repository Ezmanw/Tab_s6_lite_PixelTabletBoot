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
| Package | `dist/PixelTabletBoot-v1.1.0.zip` (888 KB) |
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

1. Download `dist/PixelTabletBoot-v1.1.0.zip`.
2. KernelSU Manager → **Modules** → **Install from storage** → pick the zip.
3. Reboot.

The installer prints your panel size and how many Samsung animation files it
hid, so you can sanity-check before rebooting.

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

## If you get a black screen while booting

The device still boots — only the animation is missing. It means Samsung's
`bootanimation` did not fall back to the zip on your firmware.

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
module/
  module.prop                   module metadata
  config.sh                     MASK_SAMSUNG_QMG, OVERRIDE_PRODUCT_OEM
  customize.sh                  install-time: hide .qmg, set permissions
  post-fs-data.sh               boot-time: cover /product and /oem paths
  system/media/bootanimation.zip
```

## Credits

The four-colour dot motif is Google's. The frames here are drawn from scratch
by the generator in `tools/`.
