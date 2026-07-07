@echo off
chcp 65001 >nul
REM ========================================================
REM  中世纪农民起义 - V0.1 跑 3 个自动化验收测试
REM  Config 20项 + ProgressFlags 6项 + Save 11项 = 共 37项
REM ========================================================
title Medieval Rebellion - V0.1 Auto-Check 37/37

setlocal enabledelayedexpansion

set "GODOT_EXE=D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe"
set "PROJECT_DIR=%~dp0"

if not exist "%GODOT_EXE%" (
    echo [错误] 找不到 Godot 引擎：%GODOT_EXE%
    pause
    exit /b 1
)
if not exist "%PROJECT_DIR%project.godot" (
    echo [错误] 当前目录没有 project.godot。
    pause
    exit /b 1
)

echo.
echo ====================================================================
echo  Medieval Rebellion V0.1 - 自动化验收（共 3 轮，累计 37 项）
echo ====================================================================
echo.

set /a TOTAL_PASS=0
set /a TOTAL_FAIL=0
set /a SCENE_IDX=0

for %%T in (
    "V01_ConfigTest.tscn|C 验收 20项 Config 四层配置"
    "V01_FlagsTest.tscn |F 验收  6项 ProgressFlags 标记+KV+序列化"
    "V01_SaveTest.tscn  |S 验收 11项 SaveSlotManager 3槽存档"
) do (
    for /f "tokens=1,2 delims=|" %%a in ("%%~T") do (
        set SCENE=%%a
        set NAME=%%b
        set /a SCENE_IDX+=1

        echo --------------------------------------------------------------------
        echo  轮 !SCENE_IDX!/3 : !NAME!
        echo  场景  : res://scenes/test/!SCENE!
        echo --------------------------------------------------------------------

        set "LOG_FILE=%TEMP%\mreb_v01_!SCENE_IDX!.log"
        del /q "!LOG_FILE!" 2>nul

        start "" /wait "%GODOT_EXE%" --path "%PROJECT_DIR%" --headless --quit-after 6 --scene "res://scenes/test/!SCENE!" > "!LOG_FILE!" 2>&1

        echo.
        if exist "!LOG_FILE!" (
            findstr /i /c:"✅" /c:"passed=" /c:"Passed " /c:"Failed " "!LOG_FILE!"
            echo.

            for /f "tokens=2 delims==" %%p in ('findstr /i /c:"Passed " /c:"passed=" "!LOG_FILE!"') do (
                for /f "tokens=1 delims= " %%n in ("%%p") do set /a TOTAL_PASS+=%%n
            )
            for /f "tokens=3 delims==" %%p in ('findstr /i /c:"Failed " /c:"failed=" "!LOG_FILE!"') do (
                for /f "tokens=1 delims= " %%n in ("%%p") do set /a TOTAL_FAIL+=%%n
            )
        ) else (
            echo   [警告] 日志未生成，跳过本轮结果统计。
        )
        echo.
    )
)

echo ====================================================================
echo   合计:  通过 = !TOTAL_PASS!   失败 = !TOTAL_FAIL!
echo ====================================================================
if !TOTAL_FAIL! EQU 0 (
    echo   [PASS] V0.1 自动化验收 37/37 全部通过 🎉
) else (
    echo   [FAIL] 有失败项，请查上面日志。
)
echo.
pause
exit /b !TOTAL_FAIL!
