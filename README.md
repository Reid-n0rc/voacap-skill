# voacap-skill

A Claude Code skill for running HF (shortwave) radio propagation
predictions using [VOACAP](https://www.voacap.com/), via the
[voacapl](https://github.com/jawatson/voacapl) Linux/GFortran port on
macOS/Linux, or the native NTIA/ITS Windows VOACAP engine on Windows.

**[reid-n0rc.github.io/voacap-skill](https://reid-n0rc.github.io/voacap-skill/)**
&mdash; what it is, how to install it, and fun things to try.

The skill lives in `.claude/skills/voacap/`. On macOS/Linux it clones and
builds `voacapl` on demand (see `setup.sh`) rather than vendoring the
engine's source in this repo, so it stays in sync with upstream; on
Windows, `setup.ps1` installs a prebuilt native engine instead (no source
build).

See [`.claude/skills/voacap/SKILL.md`](.claude/skills/voacap/SKILL.md) for
usage.

## Quick start

Install as a personal Claude Code skill with one command (works from inside
a Claude Code session, or any shell). It installs build dependencies via
Homebrew or apt, builds `voacapl`, and copies the skill to
`~/.claude/skills/voacap` so it's available in every project. CI runs this
exact script end-to-end (including the dependency-install step) on both
macOS and Linux for every change; see `.github/workflows/ci.yml`:

```
curl -fsSL https://raw.githubusercontent.com/Reid-n0rc/voacap-skill/main/install.sh | sh
```

On Windows (PowerShell), `install.ps1` installs the native NTIA/ITS Windows
VOACAP engine (`voacapw.exe`, via a silent installer) instead of building
`voacapl`. CI runs this script end-to-end on `windows-latest`; see
`.github/workflows/ci.yml`:

```
irm https://raw.githubusercontent.com/Reid-n0rc/voacap-skill/main/install.ps1 | iex
```

Then just ask Claude Code about HF propagation in any project. Or run it
directly:

```
python3 ~/.claude/skills/voacap/scripts/voacap_predict.py \
  --tx-name "London" --tx-lat 51.5 --tx-lon -0.13 \
  --rx-name "New York" --rx-lat 40.7 --rx-lon -74.0 \
  --month 9 --ssn 60 --freqs 7.1 14.2 21.2
```

Alternatively, clone this repo and use the skill from `.claude/skills/voacap/`
directly (see `.claude/skills/voacap/scripts/setup.sh`, or `setup.ps1` on
Windows).

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md): work happens on `dev`/feature
branches, `main` is PR-only and CI-gated, the skill tracks the latest
`jawatson/voacapl` release (checked daily; see
`.github/workflows/check-upstream-release.yml`), and the Windows install
path is checked daily too (`.github/workflows/check-windows-engine.yml`).

## License

This repo's own code is [MIT licensed](LICENSE). It doesn't vendor any
third-party engine source or binaries (`voacapl` is cloned/built on demand,
never committed; the Windows engine installer is downloaded, never
committed) &mdash; both engines wrap NTIA/ITS VOACAP, a U.S. government
work not subject to copyright, per
[jawatson/voacapl](https://github.com/jawatson/voacapl)'s and
[greg-hand.com](https://www.greg-hand.com/hfwin32.html)'s own licensing
notices.
