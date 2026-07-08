@echo off
setlocal
set "GODOT=D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo [02-LaunchGame][ERROR] Godot not found at: %GODOT%
  pause
  exit /b 1
)
echo.
echo ====================================================
echo   V0.2 - Launch GAME (Player Mode)
echo   Godot binary: %GODOT%
echo ====================================================
echo.
echo [INFO] Main Menu now includes a new entry:
echo        [Workshop] -> New / Edit / Built-in Templates / Test User Map
echo        (plus Start Game, Config/Flags/Save/Input tests)
echo.
cd /d "%~dp0\.."
"%GODOT%" --path "%cd%"
set EC=%ERRORLEVEL%
echo.
echo [02-LaunchGame] Exited. ExitCode=%EC%
endlocal
