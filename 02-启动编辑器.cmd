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

set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

cd /d "%PROJECT_DIR%"

if not exist "%PROJECT_DIR%\project.godot" (
    echo [ERROR] project.godot not found.
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
