@echo off
REM ========================================================
REM  Medieval Rebellion V0.1 - Open Editor
REM ========================================================
title Medieval Rebellion V0.1 - Editor

set "GODOT_EXE=D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe"

if not exist "%GODOT_EXE%" (
    echo [ERROR] Godot executable not found: %GODOT_EXE%
    echo         Edit GODOT_EXE variable at the top of this .cmd file.
    pause
    exit /b 1
)

set "CMD_DIR=%~dp0"
if "%CMD_DIR:~-1%"=="\" set "CMD_DIR=%CMD_DIR:~0,-1%"
pushd "%CMD_DIR%\..\.."
set "PROJECT_DIR=%CD%"
popd

if not exist "%PROJECT_DIR%\project.godot" (
    echo [ERROR] project.godot not found at PROJECT_DIR=%PROJECT_DIR%
    pause
    exit /b 1
)

echo.
echo ============================================
echo   Medieval Rebellion V0.1 - Open Editor
echo ============================================
echo   Godot   : %GODOT_EXE%
echo   Project : %PROJECT_DIR%
echo.
echo   Editor shortcuts:
echo     F5 - Run game
echo     F6 - Run current scene
echo     Ctrl+S - save scene / script
echo.

"%GODOT_EXE%" --path "%PROJECT_DIR%" -e
exit /b %ERRORLEVEL%
