#!/bin/sh
# Clones and builds a release of jawatson/voacapl (if needed) and sets up
# ~/itshfbc (if needed). Safe to re-run; each step is skipped if already done
# for the requested release. Re-run after a new upstream release to rebuild
# against it (pass --release <tag> to pin a specific one; default is the
# latest GitHub release).
#
# Usage: setup.sh [--release <tag>|latest]
set -e

UPSTREAM_REPO="https://github.com/jawatson/voacapl.git"
UPSTREAM_OWNER_REPO="jawatson/voacapl"
REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
VENDOR_DIR="$REPO_ROOT/vendor/voacapl"
MARKER="$REPO_ROOT/local/.voacapl-release"

RELEASE="latest"
while [ $# -gt 0 ]; do
    case "$1" in
        --release) RELEASE="$2"; shift 2 ;;
        --release=*) RELEASE="${1#--release=}"; shift ;;
        *) echo "unknown argument: $1" >&2; exit 1 ;;
    esac
done

cd "$REPO_ROOT"

if [ "$RELEASE" = "latest" ]; then
    echo "Looking up latest $UPSTREAM_OWNER_REPO release..."
    if command -v gh >/dev/null 2>&1; then
        RELEASE=$(gh api "repos/$UPSTREAM_OWNER_REPO/releases/latest" --jq .tag_name)
    else
        RELEASE=$(curl -fsSL "https://api.github.com/repos/$UPSTREAM_OWNER_REPO/releases/latest" \
            | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
    fi
    if [ -z "$RELEASE" ]; then
        echo "error: could not determine the latest release tag" >&2
        exit 1
    fi
fi
echo "Target release: $RELEASE"

CURRENT=""
[ -f "$MARKER" ] && CURRENT="$(cat "$MARKER")"

if [ "$CURRENT" != "$RELEASE" ]; then
    echo "No confirmed build of release $RELEASE (previous marker: ${CURRENT:-none}); (re)building..."
    rm -rf "$VENDOR_DIR" "$REPO_ROOT/local"
fi

if [ ! -x "$REPO_ROOT/local/bin/voacapl" ]; then
    if [ ! -d "$VENDOR_DIR" ]; then
        echo "Cloning $UPSTREAM_REPO @ $RELEASE ..."
        mkdir -p "$REPO_ROOT/vendor"
        git clone --depth 1 --branch "$RELEASE" "$UPSTREAM_REPO" "$VENDOR_DIR"
    fi

    echo "Building voacapl..."
    command -v gfortran >/dev/null 2>&1 || {
        echo "error: gfortran not found. Install it (e.g. 'sudo apt-get install gfortran' or" \
             "'brew install gcc')." >&2
        exit 1
    }
    cd "$VENDOR_DIR"
    # Always regenerate the build system: the release tarball's checked-in
    # configure/Makefile.in were generated with whatever autotools version
    # the maintainer last used, which commonly mismatches the automake/
    # autoconf installed here and causes spurious "missing aclocal-X.Y"
    # rebuild failures.
    command -v autoreconf >/dev/null 2>&1 || {
        cat >&2 <<'MSG'
error: autoreconf not found. Install autoconf/automake and supporting tools:
  Debian/Ubuntu: sudo apt-get install -y autoconf automake libtool m4 pkg-config
  macOS (Homebrew): brew install autoconf automake libtool pkg-config
MSG
        exit 1
    }
    automake --add-missing || true
    autoreconf -fi
    ./configure --prefix="$REPO_ROOT/local"
    # Serial build: some subdirectories (anttyp99) have undeclared intra-directory
    # module dependencies that break under parallel make.
    make
    make install
    cd "$REPO_ROOT"
    mkdir -p "$REPO_ROOT/local"
    echo "$RELEASE" > "$MARKER"
else
    echo "voacapl already built (release $CURRENT)."
fi

BIN_DIR="$REPO_ROOT/local/bin"
export PATH="$BIN_DIR:$PATH"

if [ ! -d "$HOME/itshfbc/run" ]; then
    echo "Running makeitshfbc to set up \$HOME/itshfbc ..."
    makeitshfbc
else
    echo "\$HOME/itshfbc already set up."
fi

# voacap.cir/voacapw.asc ship with CRLF line endings. Harmless to normalize
# on any platform, and cheap insurance against any fixed-column-read
# sensitivity to the trailing \r.
for f in "$HOME/itshfbc/run/voacap.cir" "$HOME/itshfbc/run/voacapw.asc"; do
    if [ -f "$f" ]; then
        sed -i.bak 's/\r$//' "$f"
        rm -f "$f.bak"
    fi
done

# 'batch' mode calls read_asc('VOACAP', ...), which opens the file
# 'VOACAP' // 'w.asc' = "VOACAPw.asc" (mixed case) - but the file makeitshfbc
# installs is "voacapw.asc" (all lowercase). That open silently fails and
# read_asc takes its error return with zero diagnostic output, so batch mode
# exits cleanly having processed nothing. This is a no-op on case-insensitive
# filesystems (macOS default, Windows) but breaks deterministically on Linux.
# Root-caused via a local Ubuntu 24.04 container reproduction + source
# inspection of src/voacapw/read_asc.for and voacapw.for.
if [ -f "$HOME/itshfbc/run/voacapw.asc" ] && [ ! -e "$HOME/itshfbc/run/VOACAPw.asc" ]; then
    ln -s voacapw.asc "$HOME/itshfbc/run/VOACAPw.asc"
fi

echo "Done. voacapl binary: $(command -v voacapl)"
echo "itshfbc data directory: $HOME/itshfbc"
echo "voacapl release: $RELEASE"
