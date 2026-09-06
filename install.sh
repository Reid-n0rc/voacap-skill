#!/bin/sh
# Installs voacap-skill as a personal Claude Code skill (~/.claude/skills/voacap)
# so it's available in any project, then builds the voacapl engine.
#
# Run this from inside Claude Code (or any shell) with:
#   curl -fsSL https://raw.githubusercontent.com/Reid-n0rc/voacap-skill/main/install.sh | sh
set -e

# Overridable for CI, so the test suite can exercise this exact script
# against the commit under test instead of always pulling main.
REPO_URL="${VOACAP_SKILL_REPO_URL:-https://github.com/Reid-n0rc/voacap-skill.git}"
REF="${VOACAP_SKILL_REF:-}"
SKILLS_DIR="$HOME/.claude/skills"
DEST="$SKILLS_DIR/voacap"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

install_build_deps() {
    if command -v gfortran >/dev/null 2>&1 && command -v autoreconf >/dev/null 2>&1; then
        return
    fi
    echo "Installing build dependencies (gfortran, automake, autoconf, libtool)..."
    if command -v brew >/dev/null 2>&1; then
        brew install gcc automake autoconf libtool
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y gfortran automake autoconf libtool m4 pkg-config
    else
        cat >&2 <<'MSG'
error: could not detect a package manager (brew or apt-get) to install
build dependencies automatically. Install gfortran, automake, autoconf,
libtool, m4, and pkg-config yourself, then re-run this script.
MSG
        exit 1
    fi
}

install_build_deps

echo "Fetching voacap-skill..."
if [ -n "$REF" ]; then
    git clone --depth 1 --branch "$REF" "$REPO_URL" "$TMP_DIR/repo"
else
    git clone --depth 1 "$REPO_URL" "$TMP_DIR/repo"
fi

mkdir -p "$SKILLS_DIR"
rm -rf "$DEST"
cp -R "$TMP_DIR/repo/.claude/skills/voacap" "$DEST"

echo "Installed skill to $DEST"
echo "Building voacapl engine..."
"$DEST/scripts/setup.sh"

echo
echo "Done. The voacap skill is now available in every Claude Code session."
