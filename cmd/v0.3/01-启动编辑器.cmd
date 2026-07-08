@echo off
setlocal
set "GODOT=D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe"
set "CMD_DIR=%~dp0"
if "%CMD_DIR:~-1%"=="\" set "CMD_DIR=%CMD_DIR:~0,-1%"
pushd "%CMD_DIR%\..\.."
set "PROJ_ABS=%CD%"
popd
if not exist "%GODOT%" (
  echo [01-V03-LaunchEditor][ERROR] Godot not found at: %GODOT%
  echo   Please edit this .cmd and change the GODOT variable to match your local Godot 4.6.2 path.
  exit /b 1
)
if not exist "%PROJ_ABS%\project.godot" (
  echo [01-V03-LaunchEditor][ERROR] project.godot NOT FOUND under: %PROJ_ABS%
  echo   CMD_DIR  = %CMD_DIR%
  echo   PROJ_ABS = %PROJ_ABS%
  echo   Expected: PROJ_ABS should resolve to project root with project.godot inside.
  exit /b 2
)
echo.
echo ====================================================
echo   V0.3 - Launch Godot EDITOR (Map Editor Mode)
echo   Godot binary: %GODOT%
echo   Project path: %PROJ_ABS%
echo ====================================================
echo.
echo [INFO] Once the Godot editor opens, you can:
echo        * Press F5 to run the game (Main Menu -> Workshop button)
echo        * Or open: scenes/editor/EditorMain.tscn and press F6 to run the editor directly
echo.
"%GODOT%" --editor --path "%PROJ_ABS%"
set EC=%ERRORLEVEL%
echo.
echo [01-V03-LaunchEditor] Exited. ExitCode=%EC%
endlocal
