@echo off
chcp 65001 >nul
REM %~dp0 = tools\；上一層即專案根
set "PROJ=%~dp0.."
for %%I in ("%PROJ%") do set "PROJ=%%~fI"

REM 預設為本機捷徑 Godot_v4.4.1.lnk 所指向的 exe；若要改路徑請 set GODOT=...
if not defined GODOT set "GODOT=D:\Godot\Godot_v4.4.1-stable_win64.exe"

echo 專案: %PROJ%
echo 使用: %GODOT%
"%GODOT%" --headless --path "%PROJ%" -s res://tools/run_monster_pack_cli.gd
if errorlevel 1 (
  echo 失敗。請設定環境變數 GODOT 指向 Godot 4.x 的 .exe，或用編輯器執行 BuildMonsterPackFromFolder.gd
  exit /b 1
)
echo 完成。
exit /b 0
