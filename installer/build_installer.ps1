# Собирает релизную Windows-версию и упаковывает её в установщик через Inno Setup.
# Запуск из корня проекта:
#   powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1

$ErrorActionPreference = "Stop"

# Переходим в корень проекта (на уровень выше папки installer).
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

Write-Host "==> Сборка релизной версии Flutter (Windows)..." -ForegroundColor Cyan
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw "flutter build windows завершился с ошибкой." }

# Ищем компилятор Inno Setup (ISCC.exe).
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
    Write-Host "Inno Setup не найден." -ForegroundColor Yellow
    Write-Host "Установите его командой:  winget install JRSoftware.InnoSetup" -ForegroundColor Yellow
    Write-Host "или скачайте с https://jrsoftware.org/isdl.php и запустите скрипт снова." -ForegroundColor Yellow
    exit 1
}

Write-Host "==> Компиляция установщика ($iscc)..." -ForegroundColor Cyan
& $iscc "installer\re1999_solidleaf.iss"
if ($LASTEXITCODE -ne 0) { throw "ISCC завершился с ошибкой." }

Write-Host ""
Write-Host "Готово! Установщик в installer\output\" -ForegroundColor Green
