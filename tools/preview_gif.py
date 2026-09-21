#!/usr/bin/env python3
"""
Render an animated GIF preview of the frames under build/bootanim/.

The GIF is only for eyeballing the motion on a desktop; the device plays the
PNGs in bootanimation.zip, not this.
"""

import argparse
import os
import sys

from PIL import Image


def load(path, size):
    return Image.open(path).convert("RGB").resize(size, Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="build/bootanim")
    ap.add_argument("-o", "--output", default="docs/preview.gif")
    ap.add_argument("--width", type=int, default=560)
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--loops", type=int, default=2,
                    help="how many times to repeat part1 in the preview")
    args = ap.parse_args()

    p0 = os.path.join(args.src, "part0")
    p1 = os.path.join(args.src, "part1")
    if not os.path.isdir(p0):
        sys.exit("no frames at %s; run tools/make_bootanimation.py first" % args.src)

    first = Image.open(os.path.join(p0, sorted(os.listdir(p0))[0]))
    scale = args.width / float(first.width)
    size = (args.width, int(round(first.height * scale)))

    frames = [load(os.path.join(p0, n), size) for n in sorted(os.listdir(p0))]
    loop = [load(os.path.join(p1, n), size) for n in sorted(os.listdir(p1))]
    frames += loop * args.loops

    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    frames[0].save(args.output, save_all=True, append_images=frames[1:],
                   duration=int(round(1000.0 / args.fps)), loop=0, optimize=True)
    print("wrote %s (%d frames, %.1f MiB)"
          % (args.output, len(frames), os.path.getsize(args.output) / 1048576.0))


if __name__ == "__main__":
    main()
