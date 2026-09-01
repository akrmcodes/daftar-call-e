#!/usr/bin/env python3
"""Rasterize Daftar brand masters into platform icon / splash / store slots.

Launcher icons composite the on-dark mark onto `assets/brand/background.png`
with explicit glyph scale and optical centering (`LAUNCHER_GLYPH_WIDTH_FRAC`).

Splash logos rasterize from UI SVGs onto a **transparent** canvas (not the opaque
adaptive-foreground master). Monochrome canvas colors are set in native XML.

One home-screen look: do not write byte-identical dark/night copies (store
`*-dark`, web `Icon-*-dark`, `mipmap-night-*`, `drawable-night-*dpi` launcher
layers). Still write iOS 18 `AppIcon-dark.png` and the tinted silhouette.

Requires: `pip install pillow` (optional `cairosvg` when system cairo is available).
"""

from __future__ import annotations

from io import BytesIO
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MASTERS = ROOT / "brand" / "masters"
BRAND = ROOT / "assets" / "brand"
BG_SRC = BRAND / "background.png"
FG_ON_DARK = MASTERS / "adaptive_foreground_on_dark.png"
SVG_LAUNCHER = MASTERS / "daftar_mark_on_dark.svg"
SVG_ON_DARK = BRAND / "daftar_mark_on_dark.svg"
SVG_ON_LIGHT = BRAND / "daftar_mark_on_light.svg"

# Launcher glyph width as fraction of output canvas (was ~0.26 implicit).
LAUNCHER_GLYPH_WIDTH_FRAC = 0.305

# Optical vertical nudge (fraction of canvas; positive = shift mark down).
# SVG master is geometrically centered; keep 0. Bump only if PNG fallback looks high.
LAUNCHER_OPTICAL_Y_OFFSET_FRAC = 0.0

LAUNCHER_HI_RES = 1024

# Android 12 splash animated icon — 288dp canvas; mark sized so on-screen
# diameter matches Flutter DaftarBrandMark (96dp) in the 192dp display circle.
ANDROID_SPLASH_CANVAS = 288
ANDROID_SPLASH_MARK = 144

# Per-density splash rasters (288dp logical canvas) — avoids upscaling blur on xxhdpi+.
ANDROID_SPLASH_DENSITY = {
    "drawable-mdpi": 288,
    "drawable-hdpi": 432,
    "drawable-xhdpi": 576,
    "drawable-xxhdpi": 864,
    "drawable-xxxhdpi": 1152,
}

IOS_SIZES = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

MAC_SIZES = {
    "app_icon_16.png": 16,
    "app_icon_32.png": 32,
    "app_icon_64.png": 64,
    "app_icon_128.png": 128,
    "app_icon_256.png": 256,
    "app_icon_512.png": 512,
    "app_icon_1024.png": 1024,
}

ANDROID_MIPMAP = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

ANDROID_ADAPTIVE = {
    "drawable-mdpi": 108,
    "drawable-hdpi": 162,
    "drawable-xhdpi": 216,
    "drawable-xxhdpi": 324,
    "drawable-xxxhdpi": 432,
}

_CACHED_LAUNCHER_MARK: Image.Image | None = None


def load_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def resize_rgba(img: Image.Image, size: int) -> Image.Image:
    return img.convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)


def save_rgb(img: Image.Image, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(dest, "PNG", optimize=True)


def save_rgba(img: Image.Image, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGBA").save(dest, "PNG", optimize=True)


def to_black_silhouette(mark: Image.Image) -> Image.Image:
    a = mark.split()[-1]
    black = Image.new("L", mark.size, 0)
    return Image.merge("RGBA", (black, black, black, a))


def keyed_transparent(
    img: Image.Image,
    key_rgb: tuple[int, int, int],
    tolerance: int = 24,
) -> Image.Image:
    """Remove a flat backdrop color (adaptive-icon safe-zone fill) → alpha."""
    rgba = img.convert("RGBA")
    kr, kg, kb = key_rgb
    pixels = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if (
                abs(r - kr) <= tolerance
                and abs(g - kg) <= tolerance
                and abs(b - kb) <= tolerance
            ):
                pixels[x, y] = (0, 0, 0, 0)
    return rgba


def fit_on_transparent_canvas(
    mark: Image.Image,
    mark_size: int,
    canvas_size: int,
) -> Image.Image:
    """Crop to glyph bounds, scale into mark_size, center on transparent canvas."""
    bbox = mark.getbbox()
    cropped = mark.crop(bbox) if bbox else mark
    fitted = cropped.copy()
    fitted.thumbnail((mark_size, mark_size), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    offset_x = (canvas_size - fitted.width) // 2
    offset_y = (canvas_size - fitted.height) // 2
    canvas.paste(fitted, (offset_x, offset_y), fitted)
    return canvas


def _launcher_mark_hi_res() -> Image.Image:
    """Cropped glyph at high resolution — cached for all launcher outputs."""
    global _CACHED_LAUNCHER_MARK
    if _CACHED_LAUNCHER_MARK is not None:
        return _CACHED_LAUNCHER_MARK

    try:
        import cairosvg

        png_bytes = cairosvg.svg2png(
            url=str(SVG_LAUNCHER),
            output_width=LAUNCHER_HI_RES,
            output_height=LAUNCHER_HI_RES,
        )
        mark = Image.open(BytesIO(png_bytes)).convert("RGBA")
    except (ImportError, OSError):
        mark = keyed_transparent(load_rgba(FG_ON_DARK), (0, 0, 0))

    bbox = mark.getbbox()
    _CACHED_LAUNCHER_MARK = mark.crop(bbox) if bbox else mark
    return _CACHED_LAUNCHER_MARK


def _scaled_mark(mark: Image.Image, canvas_size: int) -> Image.Image:
    target_w = max(1, round(canvas_size * LAUNCHER_GLYPH_WIDTH_FRAC))
    aspect = mark.height / mark.width
    target_h = max(1, round(target_w * aspect))
    return mark.resize((target_w, target_h), Image.Resampling.LANCZOS)


def _paste_mark_on_canvas(
    canvas: Image.Image,
    mark: Image.Image,
    canvas_size: int,
) -> None:
    offset_x = (canvas_size - mark.width) // 2
    offset_y = (
        (canvas_size - mark.height) // 2
        + round(canvas_size * LAUNCHER_OPTICAL_Y_OFFSET_FRAC)
    )
    canvas.paste(mark, (offset_x, offset_y), mark)


def render_adaptive_foreground(canvas_size: int) -> Image.Image:
    """Transparent adaptive-icon foreground aligned with full-bleed launcher."""
    mark = _scaled_mark(_launcher_mark_hi_res(), canvas_size)
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    _paste_mark_on_canvas(canvas, mark, canvas_size)
    return canvas


def composite_branded_icon(background: Image.Image, size: int) -> Image.Image:
    """Gradient launcher / store icon with scaled, optically centered mark."""
    mark = _scaled_mark(_launcher_mark_hi_res(), size)
    canvas = resize_rgba(background, size)
    _paste_mark_on_canvas(canvas, mark, size)
    return canvas.convert("RGB")


def measure_launcher_glyph_metrics(
    canvas_size: int = 1024,
) -> tuple[float, float, float]:
    """Return (width_frac, center_x_err, center_y_err) on adaptive foreground."""
    fg = render_adaptive_foreground(canvas_size)
    bbox = fg.getbbox()
    if bbox is None:
        raise RuntimeError("launcher glyph missing from adaptive foreground")

    x0, y0, x1, y1 = bbox
    width_frac = (x1 - x0 + 1) / canvas_size
    cx = (x0 + x1) / 2
    cy = (y0 + y1) / 2
    center_x_err = cx - canvas_size / 2
    center_y_err = cy - canvas_size / 2
    return width_frac, center_x_err, center_y_err


def assert_launcher_metrics(canvas_size: int = 1024) -> None:
    width_frac, center_x_err, center_y_err = measure_launcher_glyph_metrics(
        canvas_size,
    )
    if not 0.29 <= width_frac <= 0.32:
        raise AssertionError(
            f"glyph width frac {width_frac:.3f} outside [0.29, 0.32]",
        )
    if abs(center_x_err) >= 2:
        raise AssertionError(f"horizontal center error {center_x_err:.1f}px >= 2")
    if abs(center_y_err) >= 4:
        raise AssertionError(f"vertical center error {center_y_err:.1f}px >= 4")

    print(
        "launcher glyph frac="
        f"{width_frac:.3f} center_err=({center_x_err:.1f},{center_y_err:.1f})",
    )


def rasterize_svg_transparent(
    svg_path: Path,
    mark_size: int,
    canvas_size: int | None = None,
) -> Image.Image:
    """Rasterize an SVG mark with alpha; optional centered pad on transparent canvas."""
    target_canvas = canvas_size or mark_size
    try:
        import cairosvg

        png_bytes = cairosvg.svg2png(
            url=str(svg_path),
            output_width=mark_size,
            output_height=mark_size,
        )
        mark = Image.open(BytesIO(png_bytes)).convert("RGBA")
        if target_canvas == mark_size:
            return mark
        canvas = Image.new("RGBA", (target_canvas, target_canvas), (0, 0, 0, 0))
        offset = (target_canvas - mark_size) // 2
        canvas.paste(mark, (offset, offset), mark)
        return canvas
    except (ImportError, OSError):
        pass

    # Fallback: keyed adaptive masters (no system cairo / cairosvg).
    if svg_path == SVG_ON_DARK:
        keyed = keyed_transparent(load_rgba(FG_ON_DARK), (0, 0, 0))
    elif svg_path == SVG_ON_LIGHT:
        keyed = keyed_transparent(
            load_rgba(MASTERS / "adaptive_foreground_on_light.png"),
            (255, 255, 255),
        )
    else:
        raise RuntimeError(f"No raster fallback for {svg_path}")

    return fit_on_transparent_canvas(keyed, mark_size, target_canvas)


def _splash_mark_for_canvas(canvas_px: int) -> int:
    return round(canvas_px * ANDROID_SPLASH_MARK / ANDROID_SPLASH_CANVAS)


def assert_splash_density_outputs(res: Path) -> None:
    """Verify density-qualified splash PNG dimensions."""
    for folder, canvas_px in ANDROID_SPLASH_DENSITY.items():
        for name in ("splash_logo.png", "splash_logo_light.png"):
            path = res / folder / name
            if not path.is_file():
                raise AssertionError(f"missing splash asset: {path}")
            with Image.open(path) as img:
                if img.size != (canvas_px, canvas_px):
                    raise AssertionError(
                        f"{path} size {img.size} != ({canvas_px}, {canvas_px})",
                    )

    legacy_dark = res / "drawable" / "splash_logo.png"
    legacy_light = res / "drawable" / "splash_logo_light.png"
    if legacy_dark.is_file() or legacy_light.is_file():
        raise AssertionError(
            "generic drawable/splash_logo*.png must not exist — use density buckets",
        )

    print(
        "splash density buckets OK "
        f"(mdpi={ANDROID_SPLASH_DENSITY['drawable-mdpi']} … "
        f"xxxhdpi={ANDROID_SPLASH_DENSITY['drawable-xxxhdpi']})",
    )


def write_splash_logos(res: Path) -> None:
    """Transparent splash marks per DPI bucket — not opaque adaptive-foreground squares."""
    for folder, canvas_px in ANDROID_SPLASH_DENSITY.items():
        mark_px = _splash_mark_for_canvas(canvas_px)
        save_rgba(
            rasterize_svg_transparent(SVG_ON_DARK, mark_px, canvas_px),
            res / folder / "splash_logo.png",
        )
        save_rgba(
            rasterize_svg_transparent(SVG_ON_LIGHT, mark_px, canvas_px),
            res / folder / "splash_logo_light.png",
        )

    # Remove legacy mdpi-only assets that caused upscaling blur on high-DPI devices.
    for legacy in (
        res / "drawable" / "splash_logo.png",
        res / "drawable" / "splash_logo_light.png",
    ):
        if legacy.is_file():
            legacy.unlink()

    assert_splash_density_outputs(res)

    launch_logo = ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchLogo.imageset"
    save_rgba(rasterize_svg_transparent(SVG_ON_DARK, 128), launch_logo / "LaunchLogo-dark.png")
    save_rgba(rasterize_svg_transparent(SVG_ON_DARK, 256), launch_logo / "LaunchLogo-dark@2x.png")
    save_rgba(rasterize_svg_transparent(SVG_ON_DARK, 384), launch_logo / "LaunchLogo-dark@3x.png")
    save_rgba(rasterize_svg_transparent(SVG_ON_LIGHT, 128), launch_logo / "LaunchLogo-light.png")
    save_rgba(rasterize_svg_transparent(SVG_ON_LIGHT, 256), launch_logo / "LaunchLogo-light@2x.png")
    save_rgba(rasterize_svg_transparent(SVG_ON_LIGHT, 384), launch_logo / "LaunchLogo-light@3x.png")


def main() -> None:
    background = load_rgba(BG_SRC)

    branded = composite_branded_icon(background, 1024)
    tinted = to_black_silhouette(render_adaptive_foreground(1024))

    store = ROOT / "brand" / "store"
    save_rgb(branded, store / "appstore.png")
    save_rgb(composite_branded_icon(background, 512), store / "playstore.png")

    ios_set = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, px in IOS_SIZES.items():
        save_rgb(composite_branded_icon(background, px), ios_set / name)
    save_rgb(branded, ios_set / "AppIcon-dark.png")
    save_rgba(tinted, ios_set / "AppIcon-tinted.png")

    mac_set = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, px in MAC_SIZES.items():
        save_rgb(composite_branded_icon(background, px), mac_set / name)

    res = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, px in ANDROID_MIPMAP.items():
        icon = composite_branded_icon(background, px)
        save_rgb(icon, res / folder / "ic_launcher.png")
        save_rgb(icon, res / folder / "ic_launcher_round.png")

    for folder, px in ANDROID_ADAPTIVE.items():
        save_rgb(
            background.convert("RGB").resize((px, px), Image.Resampling.LANCZOS),
            res / folder / "ic_launcher_background.png",
        )
        save_rgba(render_adaptive_foreground(px), res / folder / "ic_launcher_foreground.png")

    write_splash_logos(res)

    web = ROOT / "web"
    save_rgb(composite_branded_icon(background, 32), web / "favicon.png")
    icons = web / "icons"
    save_rgb(composite_branded_icon(background, 192), icons / "Icon-192.png")
    save_rgb(composite_branded_icon(background, 512), icons / "Icon-512.png")
    save_rgb(
        composite_branded_icon(background, 192),
        icons / "Icon-maskable-192.png",
    )
    save_rgb(
        composite_branded_icon(background, 512),
        icons / "Icon-maskable-512.png",
    )

    ico_sizes = [16, 24, 32, 48, 64, 128, 256]
    ico_images = [composite_branded_icon(background, s) for s in ico_sizes]
    ico_path = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    ico_images[0].save(
        ico_path,
        format="ICO",
        sizes=[(s, s) for s in ico_sizes],
        append_images=ico_images[1:],
    )

    assert_launcher_metrics(1024)
    print("Brand rasters regenerated (launcher gradient + transparent splash marks).")


if __name__ == "__main__":
    main()
