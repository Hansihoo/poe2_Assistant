@echo off
setlocal
cd /d "%~dp0"
rem The Korean runtime has a patched SimpleGraphic.dll and Hangul-capable bitmap fonts.
set POB_KO_FORCE=1
start "" "%~dp0runtime-ko\Path{space}of{space}Building-PoE2.exe" "%~dp0src\LaunchKorean.lua" %*
exit /b 0
