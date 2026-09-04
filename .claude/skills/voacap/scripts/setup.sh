#!/bin/sh
# Clones and builds jawatson/voacapl (if needed) and sets up ~/itshfbc (if needed).
# Safe to re-run; each step is skipped if already done.
set -e

UPSTREAM_REPO="https://github.com/jawatson/voacapl.git"
REPO_ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
VENDOR_DIR="$REPO_ROOT/vendor/voacapl"
cd "$REPO_ROOT"

if ! command -v voacapl >/dev/null 2>&1 && [ ! -x "$REPO_ROOT/local/bin/voacapl" ]; then
    if [ ! -d "$VENDOR_DIR" ]; then
        echo "Cloning $UPSTREAM_REPO ..."
        mkdir -p "$REPO_ROOT/vendor"
        git clone --depth 1 "$UPSTREAM_REPO" "$VENDOR_DIR"
    else
        echo "vendor/voacapl already cloned."
    fi

    echo "Building voacapl..."
    command -v gfortran >/dev/null 2>&1 || {
        echo "error: gfortran not found. Install it (e.g. 'sudo apt-get install gfortran' or" \
             "'brew install gcc')." >&2
        exit 1
    }
    cd "$VENDOR_DIR"
    if [ ! -x ./configure ]; then
        automake --add-missing || true
        autoreconf -fi
    fi
    ./configure --prefix="$REPO_ROOT/local"
    # Serial build: some subdirectories (anttyp99) have undeclared intra-directory
    # module dependencies that break under parallel make.
    make
    make install
    cd "$REPO_ROOT"
else
    echo "voacapl already built."
fi

BIN_DIR="$REPO_ROOT/local/bin"
export PATH="$BIN_DIR:$PATH"

if [ ! -d "$HOME/itshfbc/run" ]; then
    echo "Running makeitshfbc to set up \$HOME/itshfbc ..."
    makeitshfbc
else
    echo "\$HOME/itshfbc already set up."
fi

echo "Done. voacapl binary: $(command -v voacapl)"
echo "itshfbc data directory: $HOME/itshfbc"
