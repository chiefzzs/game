@echo off
chcp 65001 >nul
REM ========================================================
REM  中世纪农民起义 - 一键 git add + commit（自动填充消息）
REM  用法：把改动内容填到命令行第一个参数（不加参数会用默认消息）
REM  例：_gitsave "feat: 增加XXX功能"
REM ========================================================
title Medieval Rebellion - Git Quick Save

cd /d "%~dp0"

set "MSG=%~1"
if "%MSG%"=="" set "MSG=chore: 自动保存 (%date:~0,4%-%date:~5,2%-%date:~8,2% %time:~0,5%)"

set "GIT_EXE="
for %%g in (git.exe) do if exist "%%~$PATH:g" set "GIT_EXE=%%~$PATH:g"

if "%GIT_EXE%"=="" (
    echo [错误] 没找到 git.exe，请先安装 Git for Windows。
    pause
    exit /b 1
)

if not exist ".git\" (
    echo [错误] 当前目录不是 git 仓库（.git 不存在）。
    pause
    exit /b 1
)

echo.
echo ============================================
echo   Git 自动提交
echo   消息: %MSG%
echo ============================================

git add -A 2>&1 | findstr /v /i "warning:"

for /f "tokens=*" %%s in ('git status --porcelain 2^>nul') do set CHANGED=%%s
if "%CHANGED%"=="" (
    echo   (无变更，无需提交)
    goto done
)

git commit -m "%MSG%" 2>&1 | findstr /v /i "warning:" | findstr /v "LF will be replaced"

:done
echo.
git --no-pager log -3 --oneline
echo.
pause
exit /b 0
