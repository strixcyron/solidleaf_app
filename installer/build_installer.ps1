# Builds an obfuscated Windows release and packs it with Inno Setup.
# From project root:
#   powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1
#
# Obfuscation: flutter --obfuscate + --split-debug-info
# Scrambles Dart symbols in data\app.so (native .exe/.dll stay as-is).
# Symbol maps go to build\debug-info\ - keep them private for crash decoding.

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$debugInfoDir = Join-Path $projectRoot "build\debug-info"
New-Item -ItemType Directory -Force -Path $debugInfoDir | Out-Null

Write-Host "==> Flutter Windows release (obfuscate)..." -ForegroundColor Cyan
flutter build windows --release `
  --obfuscate `
  --split-debug-info="$debugInfoDir"
if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed." }

$isccCandidates = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
)
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    $cmd = Get-Command iscc -ErrorAction SilentlyContinue
    if ($cmd) { $iscc = $cmd.Source }
}

if (-not $iscc) {
    Write-Host ""
    Write-Host "Inno Setup not found." -ForegroundColor Yellow
    Write-Host "Install: choco install innosetup -y" -ForegroundColor Yellow
    Write-Host "or https://jrsoftware.org/isdl.php" -ForegroundColor Yellow
    exit 1
}

Write-Host "==> Compiling installer ($iscc)..." -ForegroundColor Cyan
& $iscc "installer\re1999_solidleaf.iss"
if ($LASTEXITCODE -ne 0) { throw "ISCC failed." }

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
Write-Host "  Installer:   installer\output\SolidLeafLauncher-Setup-*.exe"
Write-Host "  Debug-info:  build\debug-info\  (keep private, do not ship)"
