@echo off
setlocal
set "GODOT=D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe"
set "CMD_DIR=%~dp0"
if "%CMD_DIR:~-1%"=="\" set "CMD_DIR=%CMD_DIR:~0,-1%"
pushd "%CMD_DIR%\..\.."
set "PROJ_ABS=%CD%"
popd
if not exist "%GODOT%" (
  echo [02-LaunchGame][ERROR] Godot not found at: %GODOT%
  pause
  exit /b 1
)
if not exist "%PROJ_ABS%\project.godot" (
  echo [02-LaunchGame][ERROR] project.godot NOT FOUND under: %PROJ_ABS%
  echo   CMD_DIR  = %CMD_DIR%
  echo   PROJ_ABS = %PROJ_ABS%
  pause
  exit /b 2
)
echo.
echo ====================================================
echo   V0.2 - Launch GAME (Player Mode)
echo   Godot binary: %GODOT%
echo   Project path: %PROJ_ABS%
echo ====================================================
echo.
echo [INFO] Main Menu now includes a new entry:
echo        [Workshop] -> New / Edit / Built-in Templates / Test User Map
echo        (plus Start Game, Config/Flags/Save/Input tests)
echo.
"%GODOT%" --path "%PROJ_ABS%"
set EC=%ERRORLEVEL%
echo.
echo [02-LaunchGame] Exited. ExitCode=%EC%
endlocal
