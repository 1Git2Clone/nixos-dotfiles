"""Render BB's UI and syntax palettes from Caelestia's runtime scheme."""

import argparse
import json
import re
from pathlib import Path


def rgb(colour):
    return [int(colour[i : i + 2], 16) / 255 for i in (1, 3, 5)]


def luminance(colour):
    channels = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in rgb(colour)]
    return sum(v * w for v, w in zip(channels, (0.2126, 0.7152, 0.0722)))


def contrast(first, second):
    lo, hi = sorted((luminance(first), luminance(second)))
    return (hi + 0.05) / (lo + 0.05)


def on_colour(background):
    return max(("#000000", "#ffffff"), key=lambda c: contrast(c, background))


def readable(colour, canvas, ink):
    for step in range(21):
        ratio = step / 20
        mixed = "#" + "".join(f"{round((a * (1 - ratio) + b * ratio) * 255):02x}" for a, b in zip(rgb(colour), rgb(ink)))
        if contrast(mixed, canvas) >= 4.5:
            return mixed
    return ink


def render(scheme, destination):
    colours = scheme["colours"]

    def colour(key):
        value = colours[key].removeprefix("#")
        if not re.fullmatch(r"[0-9a-fA-F]{6}", value):
            raise ValueError(f"Invalid Caelestia colour: {key}")
        return "#" + value.lower()

    current_mode = scheme["mode"]
    if current_mode not in ("light", "dark"):
        raise ValueError("Caelestia mode must be light or dark")
    destination.mkdir(parents=True, exist_ok=True)

    def write(name, content):
        target = destination / name
        temporary = target.with_suffix(target.suffix + ".tmp")
        temporary.write_text(content)
        temporary.replace(target)

    css = ["/* Generated from Caelestia; edit the generator, not this file. */"]
    for mode in ("light", "dark"):
        exact = mode == current_mode
        canvas = colour("surface" if exact else "inverseSurface")
        ink = colour("onSurface" if exact else "inverseOnSurface")
        primary = colour("primary" if exact else "inversePrimary")
        if not exact:
            primary = readable(primary, canvas, ink)
        primary_fg = colour("onPrimary") if exact else on_colour(primary)
        status = {key: readable(colour(key), canvas, ink) for key in ("red", "green", "yellow", "blue", "mauve", "peach")}
        tokens = {
            "canvas": canvas,
            "ink": ink,
            "primary": primary,
            "primary-foreground": primary_fg,
            "muted-foreground": "color-mix(in oklch, var(--ink) 70%, var(--canvas))",
            "subtle-foreground": "color-mix(in oklch, var(--ink) 58%, var(--canvas))",
            "readback-foreground": "color-mix(in oklch, var(--ink) 64%, var(--canvas))",
            "destructive": colour("error"),
            "destructive-foreground": on_colour(colour("error")),
            "destructive-text": status["red"],
            "warning": status["yellow"],
            "warning-text": status["yellow"],
            "attention": status["yellow"],
            "success": status["green"],
            "diff-added": status["green"],
            "diff-removed": status["red"],
            "pr-merged": status["mauve"],
            "file-accent": primary,
        }
        for index in range(16):
            ansi = colour(f"term{index}")
            tokens[f"ansi-{index}"] = ansi
            tokens[f"ansi-bg-fg-{index}"] = on_colour(ansi)
        css.append(":root, .light {" if mode == "light" else ".dark {")
        css.extend(f"  --{key}: {value};" for key, value in tokens.items())
        css.append("}")

        scopes = [
            (["comment", "punctuation.definition.comment"], readable(colour("subtext0"), canvas, ink)),
            (["keyword", "storage", "storage.type"], status["mauve"]),
            (["string", "markup.inserted"], status["green"]),
            (["constant.numeric", "constant.language"], status["peach"]),
            (["entity.name.function", "support.function"], status["blue"]),
            (["entity.name.type", "support.type", "entity.name.tag"], primary),
            (["variable", "variable.parameter"], ink),
            (["markup.deleted", "invalid"], status["red"]),
        ]
        code_theme = {
            "name": f"Caelestia {mode}",
            "type": mode,
            "colors": {
                "editor.background": canvas,
                "editor.foreground": ink,
                "editorLineNumber.foreground": readable(colour("subtext0"), canvas, ink),
                "textLink.foreground": primary,
                "diffEditor.insertedTextBackground": status["green"] + "25",
                "diffEditor.removedTextBackground": status["red"] + "25",
            },
            "tokenColors": [{"scope": scope, "settings": {"foreground": value}} for scope, value in scopes],
        }
        write(f"pierre-{mode}.json", json.dumps(code_theme, indent=2) + "\n")
    write("theme.css", "\n".join(css) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scheme", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    render(json.loads(args.scheme.read_text()), args.destination)
