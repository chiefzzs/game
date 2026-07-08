@echo off
setlocal
set "GODOT=D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe"
set "CMD_DIR=%~dp0"
if "%CMD_DIR:~-1%"=="\" set "CMD_DIR=%CMD_DIR:~0,-1%"
pushd "%CMD_DIR%\..\.."
set "PROJ_ABS=%CD%"
popd
if not exist "%GODOT%" (
  echo [03-AutoAcceptV0.3][ERROR] Godot not found: %GODOT%
  exit /b 1
)
if not exist "%PROJ_ABS%\project.godot" (
  echo [03-AutoAcceptV0.3][ERROR] project.godot NOT FOUND under: %PROJ_ABS%
  exit /b 2
)
echo.
echo ============================================================
echo   V0.3 AUTOMATIC ACCEPTANCE TEST (Headless, 5 phases)
echo   Project path: %PROJ_ABS%
echo ============================================================
echo.
echo [Phase 1/5] Existence check - V0.3 combat module files
set "MISSING="
for %%f in (
  "autoload\InputBus.gd"
  "autoload\GameEvents.gd"
  "autoload\SaveSlotManager.gd"
  "config\L2_balance\player.json"
  "config\L2_balance\companions.json"
  "config\L2_balance\enemies.json"
  "config\L2_balance\combat_formula.json"
  "config\L2_balance\pickups.json"
  "scripts\combat\CombatDamageCalculator.gd"
  "scripts\characters\PlayerBase.gd"
  "scripts\characters\FarmerPlayer.gd"
  "scripts\characters\CompanionBase.gd"
  "scripts\characters\AxemanCompanion.gd"
  "scripts\characters\HunterCompanion.gd"
  "scripts\characters\ShepherdCompanion.gd"
  "scripts\characters\EnemyBase.gd"
  "scripts\characters\WalkSoldierEnemy.gd"
  "scripts\characters\JumpScoutEnemy.gd"
  "scripts\characters\DummyEnemy.gd"
  "scripts\characters\ProjectileArrow.gd"
  "scripts\ui\CombatHUDController.gd"
  "scripts\systems\PickupSystem.gd"
  "scripts\systems\PickupItem.gd"
  "scripts\editor\MapLoader.gd"
  "scripts\editor\CharacterBase.gd"
  "scenes\characters\Player_Farmer.tscn"
  "scenes\characters\Companion_Axeman.tscn"
  "scenes\characters\Companion_Hunter.tscn"
  "scenes\characters\Companion_Shepherd.tscn"
  "scenes\characters\Enemy_WalkSoldier.tscn"
  "scenes\characters\Enemy_JumpScout.tscn"
  "scenes\characters\Enemy_Dummy.tscn"
  "scenes\characters\ProjectileArrow.tscn"
  "scenes\characters\CombatHUD.tscn"
  "scenes\characters\PickupGold.tscn"
  "scenes\test\V03_TrainingDummy.tscn"
  "scenes\test\V03_CombatArena.tscn"
  "scripts\test\test_combat_damage.gd"
  "scripts\test\test_fsm_basic.gd"
  "scripts\test\runner_combat_damage.gd"
  "scripts\test\runner_fsm_basic.gd"
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
  echo [Phase 1/5][FAIL] Missing V0.3 combat critical files. Aborting.
  endlocal
  exit /b 3
)
echo [Phase 1/5][PASS]
echo.
echo [Phase 2/5] MapSchemaValidator (V0.2 regression) on 3 built-in templates
"%GODOT%" --no-window --headless --path "%PROJ_ABS%" -s res://scripts/editor/MapSchemaValidatorHeadless.gd
set E1=%ERRORLEVEL%
echo   [E1=%E1%]
echo.
echo [Phase 3/5] Save-Load smoke (V0.2 regression)
"%GODOT%" --no-window --headless --path "%PROJ_ABS%" -s res://scripts/editor/runner_mapio.gd
set E2=%ERRORLEVEL%
echo   [E2=%E2%]
echo.
echo [Phase 4/5] CombatDamageCalculator Headless tests (10 cases)
"%GODOT%" --no-window --headless --path "%PROJ_ABS%" -s res://scripts/test/runner_combat_damage.gd
set E3=%ERRORLEVEL%
echo   [E3=%E3%]
echo.
echo [Phase 5/5] FSM Basic Headless tests (CharacterBase + FSM, 8 cases)
"%GODOT%" --no-window --headless --path "%PROJ_ABS%" -s res://scripts/test/runner_fsm_basic.gd
set E4=%ERRORLEVEL%
echo   [E4=%E4%]
echo.
set /A TOTAL=E1+E2+E3+E4
echo ============================================================
if %TOTAL% EQU 0 (
  echo  [PASS] V0.3 - All 5 phases OK.
  endlocal
  exit /b 0
) else (
  echo  [FAIL] V0.3 - Some phases failed. Sub-codes: E1=%E1%  E2=%E2%  E3=%E3%  E4=%E4%
  endlocal
  exit /b %TOTAL%
)
