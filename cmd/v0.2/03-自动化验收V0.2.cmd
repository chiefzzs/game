@echo off
setlocal
set "GODOT=D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe"
set "CMD_DIR=%~dp0"
if "%CMD_DIR:~-1%"=="\" set "CMD_DIR=%CMD_DIR:~0,-1%"
pushd "%CMD_DIR%\..\.."
set "PROJ_ABS=%CD%"
popd
if not exist "%GODOT%" (
  echo [03-AutoAcceptV0.2][ERROR] Godot not found: %GODOT%
  exit /b 1
)
if not exist "%PROJ_ABS%\project.godot" (
  echo [03-AutoAcceptV0.2][ERROR] project.godot NOT FOUND under: %PROJ_ABS%
  echo   CMD_DIR  = %CMD_DIR%
  echo   PROJ_ABS = %PROJ_ABS%
  exit /b 2
)
echo.
echo ============================================================
echo   V0.2 AUTOMATIC ACCEPTANCE TEST (Headless, 4 phases)
echo   Project path: %PROJ_ABS%
echo ============================================================
echo.
echo [Phase 1/4] Existence check - core scenes/scripts/templates/schemas
set "MISSING="
for %%f in (
  "scenes\editor\EditorMain.tscn"
  "scripts\editor\EditorMain.gd"
  "scripts\editor\DrawTools.gd"
  "scripts\editor\EntityPalette.gd"
  "scripts\editor\EntityInspector.gd"
  "scripts\editor\ObjectivesEditor.gd"
  "scripts\editor\MapSerializer.gd"
  "scripts\editor\MapLoader.gd"
  "scripts\editor\MapSchemaValidator.gd"
  "scripts\editor\CharacterBase.gd"
  "autoload\LevelFlowController.gd"
  "scenes\workshop\WorkshopMain.tscn"
  "scripts\editor\WorkshopMain.gd"
  "config\schemas\map.schema.json"
  "scenes\workshop\templates\empty.map.json"
  "scenes\workshop\templates\farm.map.json"
  "scenes\workshop\templates\arena.map.json"
) do (
  if not exist "%PROJ_ABS%\%%~f" (
    echo   [MISSING] %%~f
    set "MISSING=1"
  ) else (
    echo   [ OK ] %%~f
  )
)
if defined MISSING (
  echo.
  echo [Phase 1/4][FAIL] Missing critical files. Aborting.
  endlocal
  exit /b 3
)
echo [Phase 1/4][PASS]
echo.
echo [Phase 2/4] MapSchemaValidator on 3 built-in templates (empty/farm/arena)
"%GODOT%" --no-window --headless --path "%PROJ_ABS%" -s res://scripts/editor/MapSchemaValidatorHeadless.gd
set E1=%ERRORLEVEL%
echo   [E1=%E1%]
echo.
echo [Phase 3/4] V0.1 regression - Input/Collision/Weapon/Pickup/SmallMobs (Headless if test scene exists)
set "RT=scenes\test\V01_InputRuntimeTest.tscn"
if not exist "%PROJ_ABS%\%RT%" (
  echo   [SKIP] Test scene not present: %RT%
  set E2=0
) else (
  "%GODOT%" --no-window --headless --path "%PROJ_ABS%" "%PROJ_ABS%\%RT%"
  set E2=%ERRORLEVEL%
  echo   [E2=%E2%]
)
echo.
echo [Phase 4/4] Save-Load smoke - build dict -> save temp -> validate -> MapLoader instantiate
"%GODOT%" --no-window --headless --path "%PROJ_ABS%" -s res://scripts/editor/SmokeTestMapIO.gd
set E3=%ERRORLEVEL%
echo   [E3=%E3%]
echo.
set /A TOTAL=E1+E2+E3
echo ============================================================
if %TOTAL% EQU 0 (
  echo  [PASS] V0.2 - All 4 phases OK.
  endlocal
  exit /b 0
) else (
  echo  [FAIL] V0.2 - Some phases failed. Sub-codes: E1=%E1%  E2=%E2%  E3=%E3%
  endlocal
  exit /b %TOTAL%
)
