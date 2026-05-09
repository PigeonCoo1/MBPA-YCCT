@echo off
REM Random Edge Searcher launcher
REM Runs the PowerShell script in this folder. Close this window or press Ctrl+C to stop.
title Random Edge Searcher
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0random_edge_searcher.ps1"
echo.
echo Script exited. Press any key to close this window.
pause >nul
