# Установщик Windows-версии

Здесь лежат файлы для сборки установщика (`setup.exe`) на базе **Inno Setup**.

## Быстрый способ

Из корня проекта:

```powershell
powershell -ExecutionPolicy Bypass -File installer\build_installer.ps1
```

Скрипт сам соберёт **обфусцированный** релиз
(`flutter build windows --release --obfuscate --split-debug-info=...`)
и упакует его в установщик. Готовый файл появится в `installer\output\`.

Карты символов для расшифровки крашей: `build\debug-info\` — **не** кладите
их в установщик и не выкладывайте публично.

## Что нужно установить один раз

Компилятор Inno Setup:

```powershell
winget install JRSoftware.InnoSetup
```

(или скачать с https://jrsoftware.org/isdl.php)

## Ручной способ

```powershell
flutter build windows --release
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\re1999_solidleaf.iss
```

## Файлы

- `re1999_solidleaf.iss` — скрипт Inno Setup (имя, версия, ярлыки, иконка).
- `build_installer.ps1` — автоматическая сборка релиза + установщика.
- `output\` — сюда складывается готовый `SolidLeafLauncher-Setup-<версия>.exe`.

## Примечания

- Версия и название задаются вверху `re1999_solidleaf.iss`
  (`MyAppVersion`, `MyAppName`). Держите их в синхроне с `pubspec.yaml`.
- На целевом ПК может понадобиться
  [Visual C++ Redistributable (x64)](https://aka.ms/vs/17/release/vc_redist.x64.exe),
  если он ещё не установлен в системе.
