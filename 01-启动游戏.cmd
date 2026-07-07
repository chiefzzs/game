@echo off
chcp 65001 >nul
REM ========================================================
REM  中世纪农民起义 - V0.1 一键启动游戏
REM  上帝引擎：D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe
REM ========================================================
title Medieval Rebellion - V0.1 Game

set "GODOT_EXE=D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe"

if not exist "%GODOT_EXE%" (
    echo [错误] 找不到 Godot 引擎：%GODOT_EXE%
    echo 请检查本机 Godot 安装路径，或编辑本 .cmd 文件顶部的 GODOT_EXE 变量。
    pause
    exit /b 1
)

set "PROJECT_DIR=%~dp0"
if not exist "%PROJECT_DIR%project.godot" (
    echo [错误] 当前目录没有 project.godot，本批处理必须放在工程根目录。
    pause
    exit /b 1
)

echo.
echo ============================================
echo   Medieval Rebellion V0.1 - 启动游戏
echo ============================================
echo   上帝引擎: %GODOT_EXE%
echo   工程目录: %PROJECT_DIR%
echo.
echo   快捷键说明：
echo     F1 / F2 / F3 / F4  -> 切换4个验收测试场景
echo     Esc / P / Start    -> 触发暂停信号
echo.

"%GODOT_EXE%" --path "%PROJECT_DIR%"

exit /b %ERRORLEVEL%
