# voacap-skill

A Claude Code skill for running HF (shortwave) radio propagation
predictions using [VOACAP](https://www.voacap.com/), via the
[voacapl](https://github.com/jawatson/voacapl) Linux/GFortran port on
macOS/Linux, or the native NTIA/ITS Windows VOACAP engine on Windows.

**[reid-n0rc.github.io/voacap-skill](https://reid-n0rc.github.io/voacap-skill/)**
&mdash; what it is, how to install it, and fun things to try.

The skill lives in `skills/voacap/`. On macOS/Linux it clones and
builds `voacapl` on demand (see `setup.sh`) rather than vendoring the
engine's source in this repo, so it stays in sync with upstream; on
Windows, `setup.ps1` installs a prebuilt native engine instead (no source
build).

See [`skills/voacap/SKILL.md`](skills/voacap/SKILL.md) for usage.

## Quick start

This repo is a Claude Code plugin. From inside a Claude Code session:

```
/plugin marketplace add Reid-n0rc/voacap-skill
/plugin install voacap
```

That's it. The plugin's `SessionStart` hook builds `voacapl` (macOS/Linux)
or installs the native Windows VOACAP engine automatically the first time
you start a session with it enabled -- no separate build step, no
dependency installation to run by hand. Then just ask Claude Code about HF
propagation in any project.

You can also run the prediction script directly once it's installed:

```
python3 ~/.claude/plugins/.../voacap-skill/skills/voacap/scripts/voacap_predict.py \
  --tx-name "London" --tx-lat 51.5 --tx-lon -0.13 \
  --rx-name "New York" --rx-lat 40.7 --rx-lon -74.0 \
  --month 9 --ssn 60 --freqs 7.1 14.2 21.2
```

(The exact path depends on where Claude Code installs plugins; ask Claude
Code to run the skill instead of guessing the path yourself.)

### Manual install (without the plugin manager)

If you'd rather not use `/plugin`, `install.sh`/`install.ps1` do the same
work by hand: clone the repo, install build dependencies, build `voacapl`
(or the Windows engine), and copy the skill to `~/.claude/skills/voacap`
so it's available in every project via Claude Code's older skills
mechanism. CI runs both scripts end-to-end (including the
dependency-install step) on macOS, Linux, and Windows for every change;
see `.github/workflows/ci.yml`.

macOS/Linux:

```
curl -fsSL https://raw.githubusercontent.com/Reid-n0rc/voacap-skill/main/install.sh | sh
```

Windows (PowerShell):

```
irm https://raw.githubusercontent.com/Reid-n0rc/voacap-skill/main/install.ps1 | iex
```

Then run the prediction script directly:

```
python3 ~/.claude/skills/voacap/scripts/voacap_predict.py \
  --tx-name "London" --tx-lat 51.5 --tx-lon -0.13 \
  --rx-name "New York" --rx-lat 40.7 --rx-lon -74.0 \
  --month 9 --ssn 60 --freqs 7.1 14.2 21.2
```

Alternatively, clone this repo and use the skill from `skills/voacap/`
directly (see `skills/voacap/scripts/setup.sh`, or `setup.ps1` on
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
