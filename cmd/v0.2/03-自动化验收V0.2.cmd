@echo off
chcp 65001 > nul
setlocal
set "GODOT=D:\tools\game\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe"
set "PROJ=%~dp0\.."
if not exist "%GODOT%" (
  echo [03-自动化验收V0.2] ❌ 找不到 Godot: %GODOT%
  exit /b 1
)
pushd "%PROJ%"
set "PROJ_ABS=%CD%"
echo.
echo ==========================================================
echo   V0.2 迭代2 —— 自动化验收 (Headless)
echo ==========================================================
echo.
echo [Phase 1/4] 核心：场景 / 脚本 / 模板 / Schema 文件存在性检查
set "MISSING="
for %%f in (
  "scenes\editor\EditorMain.tscn"
  "scripts\editor\EditorMain.gd"
  "scripts\editor\DrawTools.gd"
  "scripts\editor\TilePalette.gd"
  "scripts\editor\EntityPalette.gd"
  "scripts\editor\EntityInspector.gd"
  "scripts\editor\ObjectivesEditor.gd"
  "scripts\editor\MapSerializer.gd"
  "scripts\editor\MapLoader.gd"
  "scripts\editor\MapSchemaValidator.gd"
  "scripts\editor\CharacterBase.gd"
  "autoload\LevelFlowController.gd"
  "scenes\workshop\WorkshopMain.tscn"
  "scripts\editor\WorkshopMain.gd"
  "config\schemas\map.schema.json"
  "scenes\workshop\templates\empty.map.json"
  "scenes\workshop\templates\farm.map.json"
  "scenes\workshop\templates\arena.map.json"
) do (
  if not exist %%f (
    echo   [MISSING] %%f
    set "MISSING=1"
  ) else (
    echo   [OK] %%f
  )
)
if defined MISSING (
  echo.
  echo [Phase 1/4] ❌ 存在缺失文件，验收终止。
  popd & exit /b 2
)
echo [Phase 1/4] ✅ 通过。
echo.
echo [Phase 2/4] 地图 JSON Schema 校验：3 张官方模板 + Validator 规则
"%GODOT%" --no-window --headless --path "%PROJ_ABS%" -s res://scripts/editor/MapSchemaValidatorHeadless.gd
set E1=%ERRORLEVEL%
echo   [E1=%E1%]
echo.
echo [Phase 3/4] Headless 自动化测试（V01 输入/碰撞 + 武器/拾取/小怪 回归）
set "RT=scenes\test\V01_InputRuntimeTest.tscn"
if not exist "%RT%" (
  echo   [SKIP] 测试场景未找到：%RT%
  set E2=0
) else (
  "%GODOT%" --no-window --headless --path "%PROJ_ABS%" "%RT%"
  set E2=%ERRORLEVEL%
  echo   [E2=%E2%]
)
echo.
echo [Phase 4/4] 地图保存-加载链路烟雾验证：Serializer 构造 farm 模板 → 写临时文件 → Validator校验 → MapLoader 实例化
"%GODOT%" --no-window --headless --path "%PROJ_ABS%" -s res://scripts/editor/SmokeTestMapIO.gd
set E3=%ERRORLEVEL%
echo   [E3=%E3%]
echo.
set /A TOTAL=E1+E2+E3
echo ==========================================================
if %TOTAL% EQU 0 (
  echo  ✅ V0.2 全部 4 阶段通过。
  popd & endlocal & exit /b 0
) else (
  echo  ❌ V0.2 存在失败，子阶段 ExitCode: E1=%E1%  E2=%E2%  E3=%E3%
  popd & endlocal & exit /b %TOTAL%
)
