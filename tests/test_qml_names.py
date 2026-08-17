#!/usr/bin/env python3
"""Catch QML declarations that collide with a built-in name.

qmllint is the real check, but it needs a Qt toolchain and the Omarchy shell's
import path, so it only runs on a machine that has both (`make qml-check`).
This runs anywhere and covers the failure mode that actually bites: declaring a
property whose name a base type already owns.

`property var state` on an Item is the example — QQuickItem owns `state` for its
own state machine, the redeclaration is a hard error, and nothing catches it
until the shell tries to load the plugin. Same for `property bool enabled`,
which would also stop the object receiving input rather than merely greying it
out. Both were real bugs here.

A property and a signal cannot share a name either, since a property generates
a `<name>Changed` signal and a signal generates a `<name>` handler slot.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# QQuickItem, and the positioners and shapes built on it. Deliberately only the
# names a plugin might plausibly reach for — a longer list would start
# rejecting legitimate names.
ITEM = {
    "activeFocus", "activeFocusOnTab", "anchors", "antialiasing", "baselineOffset",
    "children", "childrenRect", "clip", "containmentMask", "data", "enabled",
    "focus", "height", "implicitHeight", "implicitWidth", "layer", "opacity",
    "parent", "resources", "rotation", "scale", "smooth", "state", "states",
    "transform", "transformOrigin", "transitions", "visible", "visibleChildren",
    "width", "x", "y", "z",
}
POSITIONER = {
    "add", "bottomPadding", "layoutDirection", "leftPadding", "move", "padding",
    "populate", "rightPadding", "spacing", "topPadding",
}
RECTANGLE = {"border", "color", "gradient", "radius"}

BUILTINS = {
    "Item": ITEM,
    "Column": ITEM | POSITIONER,
    "Row": ITEM | POSITIONER,
    "Grid": ITEM | POSITIONER,
    "Flow": ITEM | POSITIONER,
    "Rectangle": ITEM | RECTANGLE,
    "BorderSurface": ITEM | RECTANGLE,
    "CursorSurface": ITEM,
    "Canvas": ITEM,
    "Flickable": ITEM,
    "Text": ITEM,
    # qs.Ui types are Items with their own API; their declared properties are
    # read from source below and merged in.
    "Panel": ITEM,
}

DECLARATION = re.compile(
    r"^\s*(?:readonly\s+|required\s+|default\s+)*property\s+[\w.<>]+\s+(\w+)")
SIGNAL = re.compile(r"^\s*signal\s+(\w+)")
OPENING = re.compile(r"([A-Za-z_][\w.]*)\s*$")


def shell_type_properties(name):
    """Declared properties of a qs.Ui type, when its source is available."""
    source = Path.home() / "github" / "omarchy" / "shell" / "Ui" / f"{name}.qml"
    if not source.exists():
        return set()
    return {
        match.group(1)
        for match in (DECLARATION.match(line) for line in source.read_text().splitlines())
        if match
    }


def strip_noise(line):
    """Blank out string literals and comments so braces inside them do not count."""
    out = []
    quote = None
    index = 0
    while index < len(line):
        char = line[index]
        if quote:
            out.append(" ")
            if char == "\\":
                out.append(" ")
                index += 2
                continue
            if char == quote:
                quote = None
        elif char in "\"'":
            quote = char
            out.append(" ")
        elif char == "/" and index + 1 < len(line) and line[index + 1] == "/":
            break
        else:
            out.append(char)
        index += 1
    return "".join(out)


def check(path):
    problems = []
    stack = []           # [(type_name, {attribute names seen})]
    in_block_comment = False

    for number, raw in enumerate(path.read_text().splitlines(), start=1):
        line = raw
        if in_block_comment:
            end = line.find("*/")
            if end < 0:
                continue
            line = line[end + 2:]
            in_block_comment = False
        start = line.find("/*")
        if start >= 0:
            if "*/" in line[start:]:
                line = line[:start] + line[line.find("*/", start) + 2:]
            else:
                line = line[:start]
                in_block_comment = True

        clean = strip_noise(line)

        declaration = DECLARATION.match(line)
        signal = SIGNAL.match(line)
        if (declaration or signal) and stack:
            name = (declaration or signal).group(1)
            type_name, seen = stack[-1]
            forbidden = BUILTINS.get(type_name, set()) | shell_type_properties(type_name)
            if name in forbidden:
                problems.append(
                    f"{path.name}:{number}: `{name}` is already a property of {type_name}")
            if name in seen:
                problems.append(f"{path.name}:{number}: `{name}` is declared twice")
            if declaration and f"{name}Changed" in seen:
                problems.append(
                    f"{path.name}:{number}: `{name}` collides with the signal {name}Changed")
            if signal and name.endswith("Changed") and name[:-len("Changed")] in seen:
                problems.append(
                    f"{path.name}:{number}: signal `{name}` collides with the property "
                    f"{name[:-len('Changed')]}")
            seen.add(name)

        for index, char in enumerate(clean):
            if char == "{":
                prefix = clean[:index].rstrip()
                match = OPENING.search(prefix)
                stack.append(((match.group(1) if match else "?"), set()))
            elif char == "}":
                if not stack:
                    problems.append(f"{path.name}:{number}: unbalanced closing brace")
                else:
                    stack.pop()

    if stack:
        problems.append(f"{path.name}: {len(stack)} unclosed brace(s)")
    return problems


def main():
    files = sorted(ROOT.glob("*.qml")) + sorted((ROOT / "components").glob("*.qml"))
    if not files:
        print("no QML files found", file=sys.stderr)
        return 1
    problems = [problem for path in files for problem in check(path)]
    if problems:
        for problem in problems:
            print(problem, file=sys.stderr)
        return 1
    print(f"qml name checks passed ({len(files)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
