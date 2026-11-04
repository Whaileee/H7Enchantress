@echo off
rem Copies the mod to the game. Usage: deploy.bat   (set H7_GAME_DIR to use another game folder)
setlocal
set GAME=N:\Ubisoft\games\Might and Magic Heroes VII
if defined H7_GAME_DIR set GAME=%H7_GAME_DIR%
if not exist "%GAME%\H7ModEngine\mods" (
  echo H7ModEngine is not installed in %GAME%
  exit /b 1
)
robocopy "%~dp0H2Enchantress" "%GAME%\H7ModEngine\mods\H2Enchantress" /MIR /NJH /NJS /NDL >nul
if errorlevel 8 exit /b 1
echo Deployed to %GAME%\H7ModEngine\mods\H2Enchantress
exit /b 0
