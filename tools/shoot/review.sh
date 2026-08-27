#!/usr/bin/env bash
#
# One command to look at Moonvibe: static checks, a build, every screen captured
# offscreen, and the design linter over the results.
#
#   tools/shoot/review.sh [--no-build] [--out DIR] [--shot NAME]
#
# Everything lands in DIR: <shot>.png to look at, <shot>.json for the linter,
# lint.json for the findings. From Windows, point --out at a path under /mnt/c
# so the PNGs can be opened outside WSL:
#
#   tools/shoot/review.sh --out /mnt/c/Users/<you>/AppData/Local/Temp/moonvibe-review
#
# Nothing here touches a display server. If a shot fails, it says how far it got
# rather than leaving a black frame to be misread as a broken UI.

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="${MOONVIBE_BUILD:-$HOME/build/moonvibe}"
OUT="${MOONVIBE_REVIEW_OUT:-$HOME/moonvibe-review}"
BUILD_ENABLED=1
ONLY_SHOT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --no-build) BUILD_ENABLED=0; shift ;;
        --out) OUT="$2"; shift 2 ;;
        --shot) ONLY_SHOT="$2"; shift 2 ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

QMLLINT="${QMLLINT:-/usr/lib/qt6/bin/qmllint}"
SHOTS="$SRC/tools/shoot/shots.json"
BIN="$BUILD/app/moonvibe"

mkdir -p "$OUT"
echo "source:  $SRC"
echo "build:   $BUILD"
echo "output:  $OUT"

# ---------------------------------------------------------------- static checks

echo
echo "== static =="

# A QML file that is not in qml.qrc does not ship, and says nothing about it at
# build time -- it fails at runtime, in the one view nobody opened.
#
# HomeView.qml is deliberately out: the home screen shipped in 0.5.0 and was
# removed in 0.6.0 at the owner's request, and the file is kept in the tree in
# case it comes back in another form.
QRC_EXEMPT="HomeView.qml"

missing_from_qrc=0
for qml in "$SRC"/app/gui/*.qml; do
    name="gui/$(basename "$qml")"
    case " $QRC_EXEMPT " in *" $(basename "$qml") "*) continue ;; esac
    if ! grep -q "<file>$name</file>" "$SRC/app/qml.qrc"; then
        echo "  ERROR  $name is not listed in app/qml.qrc"
        missing_from_qrc=$((missing_from_qrc + 1))
    fi
done
[ "$missing_from_qrc" -eq 0 ] && echo "  qml.qrc lists every file in app/gui"

if [ -x "$QMLLINT" ]; then
    # qmllint cannot see the C++-registered types (AppModel, ComputerManager,
    # the Theme singleton) or resolve ids across files, so unresolved-type,
    # unqualified and missing-property are noise here by construction. What is
    # left -- syntax errors, bad bindings, deprecations -- is worth reading.
    lint_output="$("$QMLLINT" --compiler disable "$SRC"/app/gui/*.qml 2>&1 \
        | grep -vE "\[(unresolved-type|unqualified|missing-property|import)\]" \
        | grep -E "^(Error|Warning)" | head -20)"
    if [ -n "$lint_output" ]; then
        echo "$lint_output" | sed 's|^|  |'
    else
        echo "  qmllint clean"
    fi
else
    echo "  qmllint not found at $QMLLINT (skipped)"
fi

# ----------------------------------------------------------------------- build

if [ "$BUILD_ENABLED" -eq 1 ]; then
    echo
    echo "== build =="
    mkdir -p "$BUILD"
    ( cd "$BUILD" && qmake6 "$SRC/moonlight-qt.pro" >/dev/null && \
      make -j"$(nproc)" release 2>&1 | grep -E " error|Error [0-9]|\*\*\*" | head -20 )
    if [ ! -x "$BIN" ]; then
        echo "  build produced no binary at $BIN" >&2
        exit 1
    fi
    echo "  built $BIN"
fi

if [ ! -x "$BIN" ]; then
    echo "no binary at $BIN -- run without --no-build" >&2
    exit 1
fi

# ------------------------------------------------------------------------ shots

echo
echo "== shots =="

if [ -n "$ONLY_SHOT" ]; then
    names="$ONLY_SHOT"
else
    names="$(python3 -c "import json,sys; print(' '.join(json.load(open(sys.argv[1]))['shots']))" "$SHOTS")"
fi

failed=0
for shot in $names; do
    line="$(cd "$BUILD/app" && env -u WAYLAND_DISPLAY -u DISPLAY \
        MOONVIBE_SHOOT="$shot" \
        MOONVIBE_SHOOT_SCRIPT="$SHOTS" \
        MOONVIBE_SHOOT_OUT="$OUT" \
        timeout 90 ./moonvibe 2>&1 | grep -E "shoot(\[$shot\])?: (wrote|could not|timed out|grabWindow|the root|fatal|no shot|cannot read)")"

    if echo "$line" | grep -q wrote; then
        printf '  ok      %s\n' "$shot"
    else
        printf '  FAILED  %s  %s\n' "$shot" "${line:-no output}"
        failed=$((failed + 1))
    fi
done

# The in-stream drawer is not QML and cannot be captured with the others: it
# renders itself into an SDL surface. Same idea, different pipeline.
if [ -z "$ONLY_SHOT" ]; then
    ( cd "$BUILD/app" && MOONVIBE_DRAWER_PREVIEW="$OUT/drawer.bmp" ./moonvibe >/dev/null 2>&1 )
    if [ -f "$OUT/drawer.bmp" ] && command -v magick >/dev/null; then
        magick "$OUT/drawer.bmp" "$OUT/drawer.png" && rm -f "$OUT/drawer.bmp"
        echo "  ok      drawer (in-stream overlay)"
    elif [ -f "$OUT/drawer.bmp" ]; then
        echo "  ok      drawer (BMP only -- install imagemagick for a PNG)"
    else
        echo "  FAILED  drawer"
        failed=$((failed + 1))
    fi
fi

# ------------------------------------------------------------------------- lint

echo
echo "== design lint =="
python3 "$SRC/tools/shoot/designlint.py" "$OUT" \
    --theme "$SRC/app/gui/Theme.qml" \
    --json "$OUT/lint.json"
lint_status=$?

echo
echo "PNGs to look at:"
ls -1 "$OUT"/*.png 2>/dev/null | sed 's/^/  /'

if [ "$failed" -gt 0 ]; then
    echo
    echo "$failed shot(s) failed" >&2
    exit 1
fi

exit $lint_status
