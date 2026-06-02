@echo off
setlocal
cd /d "%~dp0"
node "%~dp0tools\pob-mcp\server.js"
exit /b %ERRORLEVEL%
