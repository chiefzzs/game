@echo off
setlocal
set "GODOT=D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe"
set "CMD_DIR=%~dp0"
if "%CMD_DIR:~-1%"=="\" set "CMD_DIR=%CMD_DIR:~0,-1%"
pushd "%CMD_DIR%\..\.."
set "PROJ_ABS=%CD%"
popd
if not exist "%GODOT%" (
  echo [02-LaunchGame V0.3][ERROR] Godot not found at: %GODOT%
  exit /b 1
)
if not exist "%PROJ_ABS%\project.godot" (
  echo [02-LaunchGame V0.3][ERROR] project.godot NOT FOUND under: %PROJ_ABS%
  exit /b 2
)
echo.
echo ====================================================
echo   V0.3 - Launch GAME (Combat Realization Build)
echo   Godot binary: %GODOT%
echo   Project path: %PROJ_ABS%
echo ====================================================
echo.
echo [INFO] V0.3 Combat system highlights:
echo    * Player Farmer 11-state FSM: IDLE/RUN/JUMP/DOUBLEJUMP/DASH/3xATTACK/BLOCK/HURT
echo    * 3 Companion AI (Axeman/Hunter/Shepherd): FOLLOW/ALERT/ATTACK/RETREAT
echo    * 3 Enemy AI (WalkSoldier/JumpScout/Dummy): PATROL/CHASE/ATTACK/HURT/DEAD
echo    * Damage formula: crit/backstab/block/shieldbreak/min-clamp/hp-clamp
echo    * Pickup System: enemy killed drops gold/potion, auto/manual pickup
echo    * Combat HUD: HP/Stamina bars, gold/weapon, combo count, floating damage text
echo    * Save Slot schema v2: HP/Stamina/Weapon/Gold/Team/Checkpoint
echo    * Event Bus: 15+ combat signals (damage_calculated/enemy_killed/gold_picked/combo_changed...)
echo.
echo    Shortcut: Press 1=Fist, 2=Axe, 3=Bow
echo.
"%GODOT%" --path "%PROJ_ABS%"
set EC=%ERRORLEVEL%
echo.
echo [02-LaunchGame V0.3] Exited. ExitCode=%EC%
endlocal