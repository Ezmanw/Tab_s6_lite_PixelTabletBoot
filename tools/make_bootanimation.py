#!/usr/bin/env python3
"""
Generate a Pixel-Tablet-style bootanimation.zip.

Two styles:

  dots   Four Google-coloured dots fly in as a row, swirl into a ring, then
         orbit forever.  The classic Google/Pixel tablet look.
  spark  The four-pointed Gemini spark draws itself in with a blue-to-purple
         gradient, then turns slowly.

Both render part0 (plays once) and part1 (loops until Android is ready).
Dark background by default; pass --theme light for white.

Defaults target the Galaxy Tab S6 Lite panel: 2000x1200, landscape.
"""

import argparse
import math
import os
import shutil
import subprocess
import sys
import zipfile

from PIL import Image, ImageDraw

# Google's four.  Order is clockwise from the top of the ring.
DOT_COLORS = [
    (66, 133, 244),   # blue
    (234, 67, 53),    # red
    (251, 188, 5),    # yellow
    (52, 168, 83),    # green
]

# Gemini's spark runs blue into purple.
SPARK_GRADIENT = ((66, 133, 244), (154, 66, 244))

THEMES = {
    "dark": (0, 0, 0),
    "light": (255, 255, 255),
}
SUPERSAMPLE = 8  # sprite is rendered this many times oversized, then scaled down


def ease_in_out_cubic(t):
    if t < 0.5:
        return 4 * t * t * t
    return 1 - pow(-2 * t + 2, 3) / 2


def make_disc(color, size):
    """A single antialiased RGBA dot, rendered big and scaled down."""
    big = size * SUPERSAMPLE
    img = Image.new("RGBA", (big, big), color + (0,))
    ImageDraw.Draw(img).ellipse([0, 0, big - 1, big - 1], fill=color + (255,))
    return img.resize((size, size), Image.LANCZOS)


class Canvas:
    """Shared geometry: composition size, rotation and background."""

    def __init__(self, width, height, rotate, theme, scale):
        self.bg = THEMES[theme]
        self.scale = scale
        # Compose in the orientation the viewer should see, then rotate the
        # finished frame to match the panel's native framebuffer.
        self.rotate = rotate % 360
        if self.rotate in (90, 270):
            self.cw, self.ch = height, width
        else:
            self.cw, self.ch = width, height

        self.short = min(self.cw, self.ch)
        self.cx, self.cy = self.cw / 2.0, self.ch / 2.0

    def finish(self, canvas):
        if self.rotate:
            canvas = canvas.rotate(-self.rotate, expand=True)
        return canvas

    def blank(self):
        return Image.new("RGB", (self.cw, self.ch), self.bg)


class DotsComposer(Canvas):
    """Four dots: a row that swirls into an orbiting ring."""

    def __init__(self, *a, **kw):
        Canvas.__init__(self, *a, **kw)
        short, sc = self.short, self.scale
        self.dot_r = short * 0.038 * sc   # dot radius at rest
        self.ring_r = short * 0.130 * sc  # orbit radius at rest
        self.row_gap = short * 0.105 * sc # spacing of the fly-in row

        # One sprite per colour at generous resolution; scaled per frame.
        sprite_px = int(self.dot_r * 2 * 1.6) + 2
        self.sprites = [make_disc(c, sprite_px) for c in DOT_COLORS]

    def paste_dot(self, canvas, index, x, y, radius):
        d = max(2, int(round(radius * 2)))
        sprite = self.sprites[index].resize((d, d), Image.LANCZOS)
        canvas.paste(sprite, (int(round(x - d / 2)), int(round(y - d / 2))), sprite)

    def render(self, positions):
        """positions: list of (x, y, radius) in composition space."""
        canvas = self.blank()
        for i, (x, y, r) in enumerate(positions):
            if r > 0.5:
                self.paste_dot(canvas, i, x, y, r)
        return self.finish(canvas)

    def intro_frame(self, t):
        """t in [0,1]: dots fade up in a row, then bend into the ring."""
        # Phase A (t<0.35): scale up in place.  Phase B: line -> ring.
        appear = min(1.0, t / 0.35)
        morph = ease_in_out_cubic(max(0.0, (t - 0.30) / 0.70))

        out = []
        for i in range(4):
            # Inner pair pops first, then the outer pair, so the row stays
            # visually centred the whole way in.
            delay = (abs(i - 1.5) - 0.5) * 0.9
            a = min(1.0, max(0.0, appear * 3 - delay))
            a = ease_in_out_cubic(min(1.0, a))

            row_x = self.cx + (i - 1.5) * self.row_gap
            row_y = self.cy

            # Ring target: blue on top, then clockwise.  The whole formation
            # sweeps 180 degrees on the way in, which reads as a swirl.
            angle = math.radians(-90 + i * 90) + math.radians(180) * (1 - morph)
            # Keep some radius through the middle of the sweep; collapsing all
            # the way to the centre just makes the dots pile up.
            r = self.ring_r * (0.45 + 0.55 * morph)
            ring_x = self.cx + math.cos(angle) * r
            ring_y = self.cy + math.sin(angle) * r

            x = row_x + (ring_x - row_x) * morph
            y = row_y + (ring_y - row_y) * morph
            out.append((x, y, self.dot_r * a))
        return out

    def loop_frame(self, t):
        """t in [0,1]: one full revolution, seamless at the seam."""
        spin = 2 * math.pi * t
        breathe = 1 + 0.07 * math.sin(2 * math.pi * 2 * t)

        out = []
        for i in range(4):
            angle = math.radians(-90 + i * 90) + spin
            r = self.ring_r * breathe
            x = self.cx + math.cos(angle) * r
            y = self.cy + math.sin(angle) * r
            # Each dot pulses on its own phase for a bit of life.
            scale = 1 + 0.10 * math.sin(2 * math.pi * (t * 2 + i / 4.0))
            out.append((x, y, self.dot_r * scale))
        return out


def spark_mask(size, sharpness):
    """A four-pointed Gemini-style spark: concave sides, points on the axes."""
    mask = Image.new("L", (size, size), 0)
    c = size / 2.0
    pts = []
    steps = 720
    for i in range(steps):
        th = 2 * math.pi * i / steps
        # Superellipse with an exponent above 1 pulls the sides inward, which
        # is what gives the spark its concave waist.
        cx_, sy_ = math.cos(th), math.sin(th)
        x = math.copysign(abs(cx_) ** sharpness, cx_)
        y = math.copysign(abs(sy_) ** sharpness, sy_)
        pts.append((c + x * (c - 1), c + y * (c - 1)))
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    return mask


def linear_gradient(size, top, bottom):
    """Diagonal blue-to-purple ramp, fixed in screen space."""
    grad = Image.new("RGB", (size, size))
    px = grad.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / float(2 * size - 2)
            px[x, y] = tuple(
                int(round(top[k] + (bottom[k] - top[k]) * t)) for k in range(3)
            )
    return grad


class SparkComposer(Canvas):
    """The Gemini spark, drawing itself in and then turning slowly."""

    SPRITE = 512

    def __init__(self, *a, **kw):
        Canvas.__init__(self, *a, **kw)
        self.spark_r = self.short * 0.170 * self.scale

        # The gradient stays put while only the mask turns, so a quarter turn
        # of the four-fold-symmetric spark loops seamlessly.
        self.grad = linear_gradient(self.SPRITE, *SPARK_GRADIENT)
        self.mask = spark_mask(self.SPRITE, 4.5)

    def draw(self, angle_deg, radius):
        canvas = self.blank()
        if radius > 1:
            mask = self.mask.rotate(angle_deg, resample=Image.BICUBIC)
            sprite = self.grad.copy()
            sprite.putalpha(mask)
            d = max(2, int(round(radius * 2)))
            sprite = sprite.resize((d, d), Image.LANCZOS)
            canvas.paste(sprite,
                         (int(round(self.cx - d / 2)), int(round(self.cy - d / 2))),
                         sprite)
        return self.finish(canvas)

    def intro_frame(self, t):
        e = ease_in_out_cubic(t)
        # Overshoot slightly on the way up so it lands rather than just stops.
        overshoot = 1 + 0.07 * math.sin(math.pi * e)
        return (-120 + 120 * e, self.spark_r * e * overshoot)

    def loop_frame(self, t):
        breathe = 1 + 0.05 * math.sin(2 * math.pi * t)
        return (90.0 * t, self.spark_r * breathe)


def save_frame(img, path, colors):
    # Quantizing keeps the frames small.  bootanimation.zip is stored
    # uncompressed, so the PNG's own size is the size on disk.
    img.convert("P", palette=Image.ADAPTIVE, colors=colors).save(
        path, "PNG", optimize=True
    )


def build(args):
    work = os.path.join(args.workdir, "bootanim")
    if os.path.isdir(work):
        shutil.rmtree(work)
    p0 = os.path.join(work, "part0")
    p1 = os.path.join(work, "part1")
    os.makedirs(p0)
    os.makedirs(p1)

    if args.style == "spark":
        comp = SparkComposer(args.width, args.height, args.rotate,
                             args.theme, args.scale)
        render_intro = lambda t: comp.draw(*comp.intro_frame(t))
        render_loop = lambda t: comp.draw(*comp.loop_frame(t))
    else:
        comp = DotsComposer(args.width, args.height, args.rotate,
                            args.theme, args.scale)
        render_intro = lambda t: comp.render(comp.intro_frame(t))
        render_loop = lambda t: comp.render(comp.loop_frame(t))

    n_intro = int(round(args.fps * args.intro_seconds))
    n_loop = int(round(args.fps * args.loop_seconds))

    for i in range(n_intro):
        t = i / float(n_intro - 1) if n_intro > 1 else 1.0
        save_frame(render_intro(t), os.path.join(p0, "%04d.png" % i), args.colors)
        print("\rpart0 %d/%d" % (i + 1, n_intro), end="", file=sys.stderr)
    print("", file=sys.stderr)

    for i in range(n_loop):
        # Never render t == 1.0; it is the same frame as t == 0 of the next pass.
        t = i / float(n_loop)
        save_frame(render_loop(t), os.path.join(p1, "%04d.png" % i), args.colors)
        print("\rpart1 %d/%d" % (i + 1, n_loop), end="", file=sys.stderr)
    print("", file=sys.stderr)

    # desc.txt dimensions are the framebuffer's, i.e. after rotation.
    if args.rotate % 180 == 90:
        dw, dh = comp.ch, comp.cw
    else:
        dw, dh = comp.cw, comp.ch

    desc = "%d %d %d\np 1 0 part0\np 0 0 part1\n" % (dw, dh, args.fps)
    with open(os.path.join(work, "desc.txt"), "w") as fh:
        fh.write(desc)

    out = os.path.abspath(args.output)
    if os.path.exists(out):
        os.remove(out)
    os.makedirs(os.path.dirname(out), exist_ok=True)

    # desc.txt must be the first entry, and everything must be STORED.
    with zipfile.ZipFile(out, "w", zipfile.ZIP_STORED) as zf:
        zf.write(os.path.join(work, "desc.txt"), "desc.txt")
        for part in ("part0", "part1"):
            for name in sorted(os.listdir(os.path.join(work, part))):
                zf.write(os.path.join(work, part, name), "%s/%s" % (part, name))

    print("wrote %s (%.1f MiB, %d frames)"
          % (out, os.path.getsize(out) / 1048576.0, n_intro + n_loop))
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--width", type=int, default=2000,
                    help="visible width, as you want to see it (default 2000)")
    ap.add_argument("--height", type=int, default=1200,
                    help="visible height, as you want to see it (default 1200)")
    ap.add_argument("--rotate", type=int, default=0, choices=[0, 90, 180, 270],
                    help="rotate frames to match the panel's framebuffer")
    ap.add_argument("--style", choices=["dots", "spark"], default="dots",
                    help="dots = classic Google, spark = Gemini (default dots)")
    ap.add_argument("--scale", type=float, default=0.8,
                    help="size of the artwork relative to the screen "
                         "(default 0.8; raise for bigger)")
    ap.add_argument("--theme", choices=sorted(THEMES), default="dark",
                    help="background behind the dots (default dark)")
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--intro-seconds", type=float, default=1.5)
    ap.add_argument("--loop-seconds", type=float, default=2.0)
    ap.add_argument("--colors", type=int, default=64,
                    help="palette size per frame (default 64)")
    ap.add_argument("--workdir", default="build")
    ap.add_argument("-o", "--output", default="module/system/media/bootanimation.zip")
    build(ap.parse_args())


if __name__ == "__main__":
    main()
