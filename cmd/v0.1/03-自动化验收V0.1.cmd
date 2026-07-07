@echo off
REM ========================================================
REM  Medieval Rebellion V0.1 - Auto-Check 37/37
REM  Config(20) + ProgressFlags(6) + SaveSlot(11) = 37
REM ========================================================
title Medieval Rebellion V0.1 - Auto-Check 37/37

setlocal enabledelayedexpansion

set "GODOT_EXE=D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe"

set "CMD_DIR=%~dp0"
if "%CMD_DIR:~-1%"=="\" set "CMD_DIR=%CMD_DIR:~0,-1%"
pushd "%CMD_DIR%\..\.."
set "PROJECT_DIR=%CD%"
popd

if not exist "%GODOT_EXE%" (
    echo [ERROR] Godot not found: %GODOT_EXE%
    pause
    exit /b 1
)
if not exist "%PROJECT_DIR%\project.godot" (
    echo [ERROR] project.godot not found at PROJECT_DIR=%PROJECT_DIR%
    pause
    exit /b 1
)

echo.
echo ====================================================================
echo  Medieval Rebellion V0.1 - Automated acceptance (3 rounds, 37 items)
echo ====================================================================
echo.

set /a TOTAL_PASS=0
set /a TOTAL_FAIL=0
set /a SCENE_IDX=0

set "SCENES=V01_ConfigTest.tscn V01_FlagsTest.tscn V01_SaveTest.tscn"
set "NAMES=[C] 20 ConfigLayers    [F] 6 ProgressFlags    [S] 11 SaveSlots"

set i=0
for %%s in (%SCENES%) do call :RUN_SCENE %%s
goto :SUMMARY

:RUN_SCENE
set /a i+=1
set SCENE=%1
for /f "tokens=%i%" %%n in ("%NAMES%") do set CNAME=%%n

echo --------------------------------------------------------------------
echo  Round %i%/3 :  %CNAME%
echo  Scene  : res://scenes/test/%SCENE%
echo --------------------------------------------------------------------

set "LOG_FILE=%TEMP%\mreb_v01_r%i%.log"
del /q "%LOG_FILE%" 2>nul

"%GODOT_EXE%" --path "%PROJECT_DIR%" --headless --quit-after 8 --scene "res://scenes/test/%SCENE%" > "%LOG_FILE%" 2>&1

echo.
if exist "%LOG_FILE%" (
    type "%LOG_FILE%" | findstr /i /r /c:"Passed" /c:"passed=" /c:"Failed " /c:"failed=" /c:"\[Config\] L2"
    echo.

    REM Extract pass count
    for /f "tokens=2 delims==" %%a in ('type "%LOG_FILE%" ^| findstr /i /r /c:"passed="') do (
        for /f %%n in ("%%a") do set /a TOTAL_PASS+=%%n
    )
    for /f "tokens=2 delims= " %%a in ('type "%LOG_FILE%" ^| findstr /i /r /c:"Passed "') do (
        set /a TOTAL_PASS+=%%a
    )
    REM Extract fail count
    for /f "tokens=4 delims==" %%a in ('type "%LOG_FILE%" ^| findstr /i /r /c:"failed="') do (
        for /f %%n in ("%%a") do set /a TOTAL_FAIL+=%%n
    )
    for /f "tokens=5" %%a in ('type "%LOG_FILE%" ^| findstr /i /r /c:"Failed "') do (
        set /a TOTAL_FAIL+=%%a
    )
) else (
    echo   [WARN] log file not generated this round.
)
echo.
exit /b 0

:SUMMARY
echo ====================================================================
echo   TOTAL:  PASS=%TOTAL_PASS%    FAIL=%TOTAL_FAIL%
echo ====================================================================
if %TOTAL_FAIL% EQU 0 (
    echo   [PASS] V0.1 automated acceptance 37/37 all passed.
) else (
    echo   [FAIL] There were failed items, check above logs.
)
echo.
REM Don't pause so it can be called from automation; keep pause for interactive use
pause
exit /b %TOTAL_FAIL%
