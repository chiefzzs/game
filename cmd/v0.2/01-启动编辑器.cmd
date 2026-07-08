@echo off
chcp 65001 > nul
setlocal
set "GODOT=D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo [01-启动编辑器] ❌ 找不到 Godot 可执行文件：%GODOT%
  echo 请确认本机安装路径，或编辑本批处理修改 GODOT 变量。
  pause & exit /b 1
)
echo.
echo ========================================
echo  V0.2 迭代2：启动地图编辑器（编辑器模式）
echo  Godot: %GODOT%
echo ========================================
echo.
echo [信息] 启动 Godot 编辑器 —— 进入后可直接打开  scenes/editor/EditorMain.tscn 场景运行，
echo        或点击主菜单 → 运行(F5)，主菜单已新增「⚒ 地图工坊」入口。
echo.
cd /d "%~dp0\.."
"%GODOT%" --editor --path "%cd%"
set EC=%ERRORLEVEL%
echo.
echo [01-启动编辑器] 已退出，ExitCode=%EC%
endlocal
