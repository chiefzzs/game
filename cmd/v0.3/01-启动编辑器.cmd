@echo off
setlocal
set "GODOT=D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe"
set "CMD_DIR=%~dp0"
if "%CMD_DIR:~-1%"=="\" set "CMD_DIR=%CMD_DIR:~0,-1%"
pushd "%CMD_DIR%\..\.."
set "PROJ_ABS=%CD%"
popd
if not exist "%GODOT%" (
  echo [01-LaunchEditor V0.3][ERROR] Godot not found at: %GODOT%
  echo   Please edit this .cmd and change the GODOT variable to match your local Godot 4.6.2 path.
  exit /b 1
)
if not exist "%PROJ_ABS%\project.godot" (
  echo [01-LaunchEditor V0.3][ERROR] project.godot NOT FOUND under: %PROJ_ABS%
  exit /b 2
)
echo.
echo ====================================================
echo   V0.3 - Launch Godot EDITOR (Combat Module Ready)
echo   Godot binary: %GODOT%
echo   Project path: %PROJ_ABS%
echo ====================================================
echo.
echo [INFO] New in V0.3 Editor:
echo        * scenes/characters/ - 10 scenes (Player 3Companions 3Enemies Arrow HUD Pickup)
echo        * scenes/test/       - V03_TrainingDummy.tscn   (press F6 to run Dummy Practice)
echo        * scenes/test/       - V03_CombatArena.tscn     (press F6 to run 5v4 Arena)
echo        * scripts/combat/CombatDamageCalculator.gd
echo        * scripts/characters/* - PlayerBase CompanionBase EnemyBase FSM scripts
echo        * scripts/test/*       - 2 headless test scripts
echo.
"%GODOT%" --editor --path "%PROJ_ABS%"
set EC=%ERRORLEVEL%
echo.
echo [01-LaunchEditor V0.3] Exited. ExitCode=%EC%
endlocal