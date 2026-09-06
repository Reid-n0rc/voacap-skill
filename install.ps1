<#
.SYNOPSIS
Installs voacap-skill as a personal Claude Code skill
(%USERPROFILE%\.claude\skills\voacap) so it's available in any project,
then installs the native Windows VOACAP engine. Windows analog of
install.sh.

.EXAMPLE
irm https://raw.githubusercontent.com/Reid-n0rc/voacap-skill/main/install.ps1 | iex
#>
param()

$ErrorActionPreference = "Stop"

# Overridable for CI, so the test suite can exercise this exact script
# against the commit under test instead of always pulling main.
$RepoUrl = if ($env:VOACAP_SKILL_REPO_URL) { $env:VOACAP_SKILL_REPO_URL } else { "https://github.com/Reid-n0rc/voacap-skill.git" }
$Ref = $env:VOACAP_SKILL_REF

$SkillsDir = Join-Path $env:USERPROFILE ".claude\skills"
$Dest = Join-Path $SkillsDir "voacap"
$TempDir = Join-Path $env:TEMP ("voacap-skill-install-" + [guid]::NewGuid().ToString("N").Substring(0, 12))

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git is required but was not found on PATH. Install Git for Windows (https://git-scm.com/download/win) and re-run."
    exit 1
}

try {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
    $CloneDir = Join-Path $TempDir "repo"

    Write-Host "Fetching voacap-skill..."
    if ($Ref) {
        git clone --depth 1 --branch $Ref $RepoUrl $CloneDir
    } else {
        git clone --depth 1 $RepoUrl $CloneDir
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Error "git clone failed with exit code $LASTEXITCODE"
        exit 1
    }

    New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null
    if (Test-Path $Dest) {
        Remove-Item -Recurse -Force $Dest
    }
    Copy-Item -Recurse -Path (Join-Path $CloneDir ".claude\skills\voacap") -Destination $Dest

    Write-Host "Installed skill to $Dest"
    Write-Host "Installing native VOACAP engine..."
    & (Join-Path $Dest "scripts\setup.ps1")
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Done. The voacap skill is now available in every Claude Code session."
