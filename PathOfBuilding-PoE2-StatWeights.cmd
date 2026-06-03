@echo off
setlocal
cd /d "%~dp0"
if not defined POB_STAT_INPUT set "POB_STAT_INPUT=%~dp0src\poe_api_response.json"
if not defined POB2_WORK_DIR set "POB2_WORK_DIR=%~dp0work"
if not defined POB_STAT_OUTPUT_DIR set "POB_STAT_OUTPUT_DIR=%POB2_WORK_DIR%\stat-weight-reports"
if not exist "%POB_STAT_OUTPUT_DIR%" mkdir "%POB_STAT_OUTPUT_DIR%"
if not defined POB_STAT_CALIBRATION if exist "%USERPROFILE%\Documents\0_MD_Data\poe\poe2\build-calibrations\martial-hollow-whirling-jewel-2026-06-01.json" set "POB_STAT_CALIBRATION=%USERPROFILE%\Documents\0_MD_Data\poe\poe2\build-calibrations\martial-hollow-whirling-jewel-2026-06-01.json"
"%~dp0runtime\Path{space}of{space}Building-PoE2.exe" "%~dp0src\LaunchStatWeights.lua" %*
exit /b %ERRORLEVEL%
