@echo off
REM Random Edge Searcher launcher (with auto-update)
REM On launch, fetches the latest random_edge_searcher.ps1 from GitHub.
REM If you have no internet (or want to pin a version), it falls back to the
REM local copy. To disable auto-update entirely, set AUTO_UPDATE=0 below.
title Random Edge Searcher
cd /d "%~dp0"

set "AUTO_UPDATE=1"
set "BRANCH=claude/random-edge-searcher-tenBD"
set "RAW=https://raw.githubusercontent.com/PigeonCoo1/MBPA-YCCT/%BRANCH%/random_edge_searcher.ps1"
set "TMP=%~dp0random_edge_searcher.ps1.new"

if "%AUTO_UPDATE%"=="1" (
    echo Checking for updates from GitHub...
    powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%RAW%' -OutFile '%TMP%' -UseBasicParsing -ErrorAction Stop } catch { exit 1 }"
    if exist "%TMP%" (
        for %%A in ("%TMP%") do (
            if %%~zA gtr 0 (
                move /y "%TMP%" "%~dp0random_edge_searcher.ps1" >nul
                echo Up to date.
            ) else (
                del "%TMP%" >nul 2>&1
                echo Update file was empty - using local copy.
            )
        )
    ) else (
        echo Could not reach GitHub - using local copy.
    )
    echo.
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0random_edge_searcher.ps1"
echo.
echo Script exited. Press any key to close this window.
pause >nul
