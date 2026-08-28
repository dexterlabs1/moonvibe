#!/usr/bin/env python3
"""Check captured Moonvibe screens against the design system.

Reads the scene dumps written by shoot mode (app/shoot) and the tokens in
app/gui/Theme.qml, then reports every place the rendered UI disagrees with them:
colours that are not tokens, type that is not on the ramp, text the user cannot
read or cannot fit, and controls too small for a thumb.

This is the half of design review that does not need eyes. It catches what
looking cannot -- a 14px font among 15px ones, a #1a1d2b that should have been
Theme.panel, a 4.3:1 contrast ratio -- and it never gets bored on the ninth
screen. Judging whether a screen is any good is still a human (or model) job,
done by reading the PNGs next to these findings.

    python3 tools/shoot/designlint.py <dump-dir> [--theme app/gui/Theme.qml]
                                      [--json report.json] [--verbose]

Findings are grouped: one line per distinct problem with a count and an example,
because forty off-token colours on one screen is one decision, not forty.
Deliberate exceptions live in lint-ignore.json and are always reported as a
count -- an exception nobody can see is indistinguishable from a missed bug.

Exit code is 1 if anything at error severity survived, 0 otherwise.
"""

import argparse
import colorsys
import json
import os
import re
import sys

SEVERITY_ORDER = {"error": 0, "warn": 1, "info": 2}

# Ancestors that clip what they contain, so their children being outside the
# window is scrolling rather than a layout escaping the screen. Qt's Flickable
# only sets clip when asked, but nothing inside one is ever drawn beyond it.
CLIPPING_TYPES = {
    "Flickable",
    "ScrollView",
    "ListView",
    "GridView",
    "PathView",
    "StackView",
    "SwipeView",
    "Popup",
    "Menu",
    "Drawer",
}


# ---------------------------------------------------------------- theme tokens


def parse_theme(path):
    """Pull the design tokens straight out of Theme.qml.

    The linter reads the same file the UI does, so a token change never leaves
    the rules checking against a stale copy.
    """
    text = open(path, encoding="utf-8").read()

    colors = {}
    for name, value in re.findall(
        r'readonly\s+property\s+color\s+(\w+)\s*:\s*"(#[0-9a-fA-F]{6,8})"', text
    ):
        colors[name] = value.lower()

    ints = {}
    for name, value in re.findall(r"readonly\s+property\s+int\s+(\w+)\s*:\s*(\d+)", text):
        ints[name] = int(value)

    strings = {}
    for name, value in re.findall(
        r'readonly\s+property\s+string\s+(\w+)\s*:\s*"([^"]+)"', text
    ):
        strings[name] = value

    return {"colors": colors, "ints": ints, "strings": strings}


def rgb(value):
    """'#rrggbb' or '#aarrggbb' -> (r, g, b), or None."""
    if not value or not value.startswith("#"):
        return None
    digits = value[1:]
    if len(digits) == 8:
        digits = digits[2:]
    if len(digits) != 6:
        return None
    return tuple(int(digits[i:i + 2], 16) for i in (0, 2, 4))


def alpha_of(value):
    if value and len(value) == 9:
        return int(value[1:3], 16)
    return 255


def relative_luminance(color):
    def channel(v):
        v = v / 255.0
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

    r, g, b = (channel(c) for c in color)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(first, second):
    a, b = relative_luminance(first), relative_luminance(second)
    lighter, darker = max(a, b), min(a, b)
    return (lighter + 0.05) / (darker + 0.05)


def is_monogram_color(color):
    """True for the placeholder-tile gradient colours.

    Theme.monogramTop/Bottom generate a colour per app name --
    hsla(hueFor(name), 0.32, 0.30) and hsla(hueFor(name), 0.38, 0.11) -- so they
    are legitimately not in the palette. Recognise them by their saturation and
    lightness instead of trying to enumerate every hue.
    """
    r, g, b = (c / 255.0 for c in color)
    _, lightness, saturation = colorsys.rgb_to_hls(r, g, b)
    for want_s, want_l in ((0.32, 0.30), (0.38, 0.11)):
        if abs(saturation - want_s) < 0.06 and abs(lightness - want_l) < 0.05:
            return True
    return False


# ---------------------------------------------------------------------- walking


def walk(node, path, parents, out):
    """Depth-first walk yielding (node, readable path, ancestor list)."""
    label = node.get("type", "?")
    if node.get("name"):
        label += "#" + node["name"]
    elif node.get("text"):
        text = node["text"]
        label += ' "' + (text[:24] + "…" if len(text) > 24 else text) + '"'

    here = path + [label]
    out.append((node, " > ".join(here[-4:]), parents))

    for child in node.get("children", []):
        walk(child, here, parents + [node], out)


# ------------------------------------------------------------------------ rules


def check_shot(dump, theme, findings):
    shot = dump.get("shot", "?")
    window_w = dump.get("width", 0)
    window_h = dump.get("height", 0)

    palette = {rgb(v) for v in theme["colors"].values()}
    palette.discard(None)

    ramp = {
        theme["ints"][k]
        for k in ("fsDisplay", "fsTitle", "fsBody", "fsLabel", "fsMicro")
        if k in theme["ints"]
    }
    families = {theme["strings"].get("fontBody"), theme["strings"].get("fontDisplay")}
    families.discard(None)

    control_height = theme["ints"].get("controlHeight", 44)
    radii = {
        theme["ints"].get("cardRadius", 12),
        theme["ints"].get("capsuleRadius", 10),
        theme["ints"].get("controlRadius", 8),
    }

    nodes = []
    walk(dump["root"], [], [], nodes)

    def report(severity, rule, bucket, path, detail):
        findings.append(
            {
                "shot": shot,
                "severity": severity,
                "rule": rule,
                "bucket": bucket,
                "path": path,
                "detail": detail,
            }
        )

    for node, path, parents in nodes:
        color = node.get("color")
        text = node.get("text")

        # Colours that are not tokens. A fully transparent fill is not a colour,
        # it is the absence of one.
        if color and alpha_of(color) > 8:
            value = rgb(color)
            if value and value not in palette and not is_monogram_color(value):
                report(
                    "warn",
                    "color-off-token",
                    color,
                    path,
                    f"{color} is not a Theme colour",
                )

        if text:
            size = node.get("fontSize", 0)
            family = node.get("fontFamily")

            # scenedump writes point sizes as negatives. On a Deck held at arm's
            # length, type measured in points is type whose size depends on what
            # the compositor claims the DPI is.
            if size < 0:
                report(
                    "warn",
                    "type-in-points",
                    f"{-size}pt",
                    path,
                    f"sized in points ({-size}pt); the ramp is in pixels",
                )
            elif size and size not in ramp:
                report(
                    "warn",
                    "type-off-ramp",
                    f"{size}px",
                    path,
                    f"{size}px is not on the ramp {sorted(ramp)}",
                )

            if family and family not in families:
                report(
                    "warn",
                    "font-off-family",
                    family,
                    path,
                    f"'{family}' is neither {' nor '.join(sorted(families))}"
                    " -- a surface fell back to a stock Qt face",
                )

            # Contrast, against the background actually rendered behind the text.
            # Skip text that is effectively invisible: a fully transparent colour
            # paints nothing, so it has no contrast to fail (e.g. the Material
            # placeholder MvTextField hides behind its own drawn one). rgb()
            # discards the alpha, so this guard has to consult it separately.
            fg, bg = rgb(color), rgb(node.get("bgSampled"))
            if fg and bg and alpha_of(color) > 8:
                ratio = contrast_ratio(fg, bg)
                # Point sizes come through negative; WCAG's large-text threshold
                # is in pixels.
                pixels = size if size >= 0 else -size * 96.0 / 72.0
                large = pixels >= 22 or (
                    pixels >= 18 and node.get("fontWeight", 400) >= 700
                )
                floor = 3.0 if large else 4.5
                if ratio < floor:
                    # A greyed-out control is meant to recede. Still worth
                    # listing, never worth failing on.
                    disabled = node.get("enabled") is False or any(
                        p.get("enabled") is False for p in parents
                    )
                    if disabled:
                        severity = "info"
                    else:
                        severity = "error" if ratio < floor - 1.0 else "warn"
                    report(
                        severity,
                        "contrast-low",
                        f"{color} on {node['bgSampled']} at {size}px",
                        path,
                        f"{ratio:.2f}:1, needs {floor}:1"
                        + (" (disabled control)" if disabled else ""),
                    )

            # Text that does not fit and is not allowed to elide is text nobody
            # can read the end of. elide 0 is Text.ElideNone.
            #
            # Only judge the item that paints the glyphs. A control (CheckBox,
            # Button) carries the same text, but its implicitWidth is the
            # single-line width and it has no elide property, so a label that
            # wraps correctly inside it would be reported as clipped. Its Text
            # child is the one that knows whether it elided.
            paints_text = not any("text" in c for c in node.get("children", []))
            if paints_text and node.get("elide", 0) == 0:
                if node.get("implicitW", 0) > node.get("w", 0) + 0.5:
                    report(
                        "error",
                        "text-clipped",
                        "width",
                        path,
                        f"needs {node['implicitW']:.0f}px, has {node['w']:.0f}px,"
                        " and does not elide",
                    )
                elif node.get("implicitH", 0) > node.get("h", 0) + 0.5:
                    report(
                        "error",
                        "text-clipped",
                        "height",
                        path,
                        f"needs {node['implicitH']:.0f}px of height,"
                        f" has {node['h']:.0f}px",
                    )

        # Thumb-sized targets. Only leaves: a Row that happens to contain a
        # button is not itself the thing being pressed.
        if node.get("interactive"):
            has_interactive_child = any(
                child.get("interactive") for child in node.get("children", [])
            )
            if not has_interactive_child:
                height, width = node.get("h", 0), node.get("w", 0)
                if 0 < height < control_height or 0 < width < control_height:
                    report(
                        "warn",
                        "hit-target-small",
                        f"{width:.0f}x{height:.0f}",
                        path,
                        f"{width:.0f}x{height:.0f}px, below the"
                        f" {control_height}px floor",
                    )

        # Radii that are neither a token nor a true pill. A pill is round on its
        # short axis, so measure against the smaller dimension -- otherwise a
        # tall narrow shape (a scrollbar handle, a focus bar) reads as off-scale
        # for being exactly as round as it can be.
        radius = node.get("radius")
        if radius:
            short = min(node.get("w", 0), node.get("h", 0))
            pill = abs(radius - short / 2) < 1.5
            if not pill and round(radius) not in radii:
                report(
                    "info",
                    "radius-off-scale",
                    f"{radius:g}px",
                    path,
                    f"{radius:g}px is neither {sorted(radii)} nor a pill",
                )

        # Anything drawn outside the window that nothing is clipping. Content
        # inside a scroller is below the fold, not lost.
        inside_clipper = any(
            p.get("clip") or p.get("type") in CLIPPING_TYPES for p in parents
        )
        if not inside_clipper:
            x, y = node.get("x", 0), node.get("y", 0)
            right, bottom = x + node.get("w", 0), y + node.get("h", 0)
            if right < -1 or bottom < -1 or x > window_w + 1 or y > window_h + 1:
                report(
                    "warn",
                    "offscreen",
                    "outside the window",
                    path,
                    f"at ({x:.0f}, {y:.0f}) {node.get('w', 0):.0f}x"
                    f"{node.get('h', 0):.0f}, outside {window_w:.0f}x{window_h:.0f}",
                )


# --------------------------------------------------------------------- ignoring


def load_ignores(path):
    if not path or not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as handle:
        return json.load(handle).get("ignore", [])


def is_ignored(finding, ignores):
    """An exception matches on rule, and optionally on bucket, path and shot."""
    for rule in ignores:
        if rule.get("rule") != finding["rule"]:
            continue
        if "bucket" in rule and rule["bucket"] != finding["bucket"]:
            continue
        if "pathContains" in rule and rule["pathContains"] not in finding["path"]:
            continue
        if "shot" in rule and rule["shot"] != finding["shot"]:
            continue
        return rule
    return None


# ----------------------------------------------------------------------- output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dumps", help="directory of <shot>.json scene dumps")
    parser.add_argument("--theme", default="app/gui/Theme.qml")
    parser.add_argument("--json", help="also write every finding as JSON here")
    parser.add_argument(
        "--ignore",
        default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "lint-ignore.json"),
        help="deliberate exceptions",
    )
    parser.add_argument(
        "--verbose", action="store_true", help="list every finding, not one per kind"
    )
    parser.add_argument(
        "--min-severity",
        default="info",
        choices=["error", "warn", "info"],
        help="hide findings below this severity",
    )
    args = parser.parse_args()

    theme = parse_theme(args.theme)
    if not theme["colors"]:
        print(f"designlint: no tokens found in {args.theme}", file=sys.stderr)
        return 2

    findings = []
    shots = 0
    for name in sorted(os.listdir(args.dumps)):
        if not name.endswith(".json") or name == "lint.json":
            continue
        with open(os.path.join(args.dumps, name), encoding="utf-8") as handle:
            dump = json.load(handle)
        if "root" not in dump:
            continue
        shots += 1
        check_shot(dump, theme, findings)

    ignores = load_ignores(args.ignore)
    kept, suppressed = [], {}
    for finding in findings:
        rule = is_ignored(finding, ignores)
        if rule:
            reason = rule.get("reason", rule["rule"])
            suppressed[reason] = suppressed.get(reason, 0) + 1
        else:
            kept.append(finding)

    cutoff = SEVERITY_ORDER[args.min_severity]
    shown = [f for f in kept if SEVERITY_ORDER[f["severity"]] <= cutoff]

    # Group identical problems: (shot, rule, bucket) with a count and an example.
    groups = {}
    for finding in shown:
        key = (finding["shot"], finding["rule"], finding["bucket"])
        group = groups.setdefault(
            key,
            {
                "severity": finding["severity"],
                "detail": finding["detail"],
                "paths": [],
                "count": 0,
            },
        )
        group["count"] += 1
        if SEVERITY_ORDER[finding["severity"]] < SEVERITY_ORDER[group["severity"]]:
            group["severity"] = finding["severity"]
            group["detail"] = finding["detail"]
        if len(group["paths"]) < 2:
            group["paths"].append(finding["path"])

    current_shot = None
    for key in sorted(
        groups, key=lambda k: (k[0], SEVERITY_ORDER[groups[k]["severity"]], k[1], k[2])
    ):
        shot, rule, _ = key
        group = groups[key]
        if shot != current_shot:
            current_shot = shot
            print(f"\n{shot}")
            print("-" * len(shot))

        count = f" x{group['count']}" if group["count"] > 1 else ""
        print(f"  {group['severity']:5} {rule:17} {group['detail']}{count}")
        for path in group["paths"] if args.verbose else group["paths"][:1]:
            print(f"        {path}")

    errors = sum(1 for f in kept if f["severity"] == "error")
    warns = sum(1 for f in kept if f["severity"] == "warn")
    infos = len(kept) - errors - warns

    print(
        f"\n{shots} shots checked: {errors} errors, {warns} warnings, {infos} notes"
        f" in {len(groups)} distinct problems"
    )

    by_rule = {}
    for finding in kept:
        by_rule[finding["rule"]] = by_rule.get(finding["rule"], 0) + 1
    for rule, count in sorted(by_rule.items(), key=lambda item: -item[1]):
        print(f"  {count:4}  {rule}")

    if suppressed:
        print("\nsuppressed by lint-ignore.json:")
        for reason, count in sorted(suppressed.items(), key=lambda item: -item[1]):
            print(f"  {count:4}  {reason}")

    if args.json:
        with open(args.json, "w", encoding="utf-8") as handle:
            json.dump(kept, handle, indent=2)

    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
