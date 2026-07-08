@echo off
setlocal
set "GODOT=D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo [01-LaunchEditor][ERROR] Godot not found at: %GODOT%
  echo   Please edit this .cmd and change the GODOT variable to match your local Godot 4.6.2 path.
  pause
  exit /b 1
)
echo.
echo ====================================================
echo   V0.2 - Launch Godot EDITOR (Map Editor Mode)
echo   Godot binary: %GODOT%
echo ====================================================
echo.
echo [INFO] Once the Godot editor opens, you can:
echo        * Press F5 to run the game (Main Menu -> Workshop button)
echo        * Or open: scenes/editor/EditorMain.tscn and press F6 to run the editor directly
echo.
cd /d "%~dp0\.."
"%GODOT%" --editor --path "%cd%"
set EC=%ERRORLEVEL%
echo.
echo [01-LaunchEditor] Exited. ExitCode=%EC%
endlocal
