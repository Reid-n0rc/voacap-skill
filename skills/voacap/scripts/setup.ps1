<#
.SYNOPSIS
Installs the native NTIA/ITS Windows VOACAP engine (voacapw.exe) and sets
up its itshfbc data directory. Windows analog of setup.sh.

.DESCRIPTION
Unlike setup.sh (which clones and compiles jawatson/voacapl from source),
there is no source build on Windows: this downloads a prebuilt installer
and runs it silently. The installer is itshfbc.exe, a freeware package
built by NTIA/ITS (a U.S. government work, not subject to copyright) and
distributed by Greg Hand at https://www.greg-hand.com/hfwin32.html -- see
that page and its README.txt for background. There is no versioned
release API for it (just a dated-filename directory listing), so the
default URL below is pinned to a specific snapshot; pass -InstallerUrl to
override.

Safe to re-run: skipped entirely if voacapw.exe already exists at the
target itshfbc directory.

.PARAMETER ItshfbcDir
Where to install the engine. The installer requires a DOS-conformant path
(no spaces), so this defaults to C:\itshfbc rather than a path under
%USERPROFILE%.

.PARAMETER InstallerUrl
Direct download URL for the itshfbc installer exe.
#>
param(
    [string]$ItshfbcDir = $(if ($env:VOACAP_ITSHFBC) { $env:VOACAP_ITSHFBC } else { "C:\itshfbc" }),
    [string]$InstallerUrl = $(if ($env:VOACAP_ITSHFBC_INSTALLER_URL) { $env:VOACAP_ITSHFBC_INSTALLER_URL } else { "https://www.greg-hand.com/versions/itshfbc_180417a.exe" })
)

$ErrorActionPreference = "Stop"

$EngineExe = Join-Path $ItshfbcDir "bin_win\voacapw.exe"
$Marker = Join-Path $ItshfbcDir ".voacap-skill-installer-url"

if ((Test-Path $EngineExe) -and (Test-Path $Marker) -and ((Get-Content $Marker -Raw).Trim() -eq $InstallerUrl)) {
    Write-Host "voacapw.exe already installed at $EngineExe (installer: $InstallerUrl)."
    exit 0
}

if ($ItshfbcDir -match '\s') {
    Write-Error "ItshfbcDir '$ItshfbcDir' contains spaces; the itshfbc installer requires a DOS-conformant path (see README.txt at greg-hand.com/hfwin32.html). Pick a path with no spaces, e.g. C:\itshfbc."
    exit 1
}

$TempDir = Join-Path $env:TEMP ("voacap-skill-" + [guid]::NewGuid().ToString("N").Substring(0, 12))
New-Item -ItemType Directory -Path $TempDir | Out-Null
try {
    $InstallerPath = Join-Path $TempDir "itshfbc-installer.exe"
    $LogPath = Join-Path $TempDir "install.log"

    # A real browser User-Agent, in case the mirror filters on it: PowerShell's
    # default WinHTTP-style UA is a common signal for naive bot-blocking.
    # The host also fronts downloads with a "One moment, please..." JS-reload
    # interstitial for some client IPs (seen from GitHub-hosted CI runners);
    # it sets a cookie and expects a reload a few seconds later, so retry a
    # few times with the same cookie jar and a short delay instead of failing
    # on the first non-MZ response.
    $session = $null
    $maxAttempts = 4
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        Write-Host "Downloading itshfbc installer from $InstallerUrl (attempt $attempt/$maxAttempts) ..."
        $params = @{
            Uri            = $InstallerUrl
            OutFile        = $InstallerPath
            UseBasicParsing = $true
            UserAgent      = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) voacap-skill-installer"
        }
        if ($session) { $params.WebSession = $session } else { $params.SessionVariable = "session" }
        Invoke-WebRequest @params
        if (-not $session) { $session = Get-Variable -Name session -ValueOnly }

        $bytes = [System.IO.File]::ReadAllBytes($InstallerPath)
        Write-Host "Downloaded $($bytes.Length) bytes."
        $headerText = -join ($bytes[0..1] | ForEach-Object { [char]$_ })
        if ($headerText -eq "MZ") {
            break
        }

        $previewLen = [Math]::Min(500, $bytes.Length)
        $preview = [System.Text.Encoding]::ASCII.GetString($bytes, 0, $previewLen)
        if ($attempt -eq $maxAttempts) {
            Write-Error "Downloaded file does not look like a Windows executable (expected 'MZ' header, got '$headerText'), $($bytes.Length) bytes after $maxAttempts attempts. First bytes:`n$preview"
            exit 1
        }
        Write-Host "Got a non-executable response (looks like an interstitial page); waiting 6s and retrying...`n$preview"
        Start-Sleep -Seconds 6
    }

    # Invoke-WebRequest marks the file with the Zone.Identifier
    # "downloaded from the internet" ADS. Windows Defender SmartScreen's
    # cloud reputation check on that mark-of-the-web is flaky for an old,
    # unsigned freeware installer with no reputation history -- it can
    # silently block execution ("the file or directory is corrupted and
    # unreadable") nondeterministically. Unblock-File strips the mark
    # before we try to run it.
    Unblock-File -Path $InstallerPath

    Write-Host "Installing to $ItshfbcDir (silent) ..."
    # Tarma InstallMate 9 Setup.exe command line: /install:<dir> forces
    # installer mode into a specific directory, /q1 is silent (progress box
    # only, no wizard), /b0 never reboots.
    # See https://tarma.com/support/im9/setup/cmdline.html
    $proc = Start-Process -FilePath $InstallerPath `
        -ArgumentList @("/install:`"$ItshfbcDir`"", "/q1", "/b0", "/log:`"$LogPath`"") `
        -Wait -PassThru -NoNewWindow

    if ($proc.ExitCode -ne 0) {
        Write-Error "itshfbc installer exited with code $($proc.ExitCode). Log:`n$(if (Test-Path $LogPath) { Get-Content $LogPath -Raw } else { '(no log written)' })"
        exit 1
    }
}
finally {
    Remove-Item -Recurse -Force $TempDir -ErrorAction SilentlyContinue
}

if (-not (Test-Path $EngineExe)) {
    Write-Error "Installer reported success but voacapw.exe was not found at $EngineExe. Check the itshfbc directory layout."
    exit 1
}

Set-Content -Path $Marker -Value $InstallerUrl -NoNewline

if (-not (Test-Path (Join-Path $ItshfbcDir "run"))) {
    Write-Warning "$ItshfbcDir\run does not exist; the itshfbc installer normally creates it. voacap_predict.py will fail until it does."
}

Write-Host "Done. voacapw.exe: $EngineExe"
Write-Host "itshfbc data directory: $ItshfbcDir"
