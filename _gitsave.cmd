@echo off
REM ========================================================
REM  Medieval Rebellion - Quick Git Save
REM  Usage: _gitsave "feat: add feature X"
REM         (no args -> default message with date/time)
REM ========================================================
title Medieval Rebellion - Git Quick Save

set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"
cd /d "%PROJECT_DIR%"

set "MSG=%~1"
if "%MSG%"=="" (
    for /f "tokens=1-3 delims=/ " %%a in ("%date%") do set D=%%a-%%b-%%c
    for /f "tokens=1-2 delims=:." %%a in ("%time: =0%") do set T=%%a%%b
    set MSG=chore: auto save %D% %T:~0,2%:%T:~2,2%
)

REM find git.exe
set "GIT_EXE="
for %%g in (git.exe) do if exist "%%~$PATH:g" set "GIT_EXE=%%~$PATH:g"
if "%GIT_EXE%"=="" (
    echo [ERROR] git.exe not found in PATH. Install Git for Windows first.
    pause
    exit /b 1
)

if not exist "%PROJECT_DIR%\.git\" (
    echo [ERROR] .git directory missing, this is not a git repo.
    pause
    exit /b 1
)

echo.
echo ============================================
echo   Git quick save
echo   Message: %MSG%
echo ============================================

git add -A >nul 2>&1

git status --porcelain > "%TEMP%\_mreb_gitstat.$$$" 2>nul
set CHANGED=0
for /f %%s in ('type "%TEMP%\_mreb_gitstat.$$$"') do set CHANGED=1
del /q "%TEMP%\_mreb_gitstat.$$$" 2>nul

if "%CHANGED%"=="0" (
    echo   (nothing to commit)
    goto done
)

git commit -m "%MSG%"

:done
echo.
git --no-pager log -5 --oneline
echo.
pause
exit /b 0
