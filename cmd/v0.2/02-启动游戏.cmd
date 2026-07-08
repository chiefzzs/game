@echo off
chcp 65001 > nul
setlocal
set "GODOT=D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo [02-启动游戏] ❌ 找不到 Godot 可执行文件：%GODOT%
  pause & exit /b 1
)
echo.
echo ========================================
echo  V0.2 迭代2：启动游戏
echo  Godot: %GODOT%
echo ========================================
echo.
echo [信息] 主菜单新增：⚒ 地图工坊（新建/编辑/官方模板/测试用户地图）
echo        以及：⚔ 开始游戏 / 🧪 输入碰撞(F4)
echo.
cd /d "%~dp0\.."
"%GODOT%" --path "%cd%"
set EC=%ERRORLEVEL%
echo.
echo [02-启动游戏] 已退出，ExitCode=%EC%
endlocal
