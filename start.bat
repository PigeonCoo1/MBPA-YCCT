@echo off
REM Random Edge Searcher launcher (with self-healing auto-update)
REM On launch:
REM   1. Try to fetch the latest random_edge_searcher.ps1 from GitHub.
REM   2. If anything goes wrong, restore the previous copy from backup.
REM   3. If the script file is somehow still missing, force-download it.
REM   4. Run it.
REM Set AUTO_UPDATE=0 below to pin a version.
title Random Edge Searcher
cd /d "%~dp0"

set "AUTO_UPDATE=1"
set "BRANCH=claude/random-edge-searcher-tenBD"
set "RAW=https://raw.githubusercontent.com/PigeonCoo1/MBPA-YCCT/%BRANCH%/random_edge_searcher.ps1"
set "PS_FILE=%~dp0random_edge_searcher.ps1"

if "%AUTO_UPDATE%"=="1" (
    echo Checking for updates from GitHub...
    powershell -NoProfile -Command "$dst='%PS_FILE%'; $tmp=$dst+'.new'; $bak=$dst+'.bak'; if (Test-Path $dst) { Copy-Item $dst $bak -Force }; try { Invoke-WebRequest -Uri '%RAW%' -OutFile $tmp -UseBasicParsing -ErrorAction Stop; if ((Get-Item $tmp).Length -gt 200) { Move-Item $tmp $dst -Force; Write-Host 'Up to date.'; Remove-Item $bak -Force -ErrorAction SilentlyContinue } else { Remove-Item $tmp -Force -ErrorAction SilentlyContinue; Write-Host 'Update file was empty - keeping local copy.' } } catch { if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }; Write-Host 'Could not reach GitHub - keeping local copy.' }; if (-not (Test-Path $dst) -and (Test-Path $bak)) { Move-Item $bak $dst -Force; Write-Host 'Restored previous copy from backup.' }"
    echo.
)

REM Recovery: if the script file is somehow missing, force-download a fresh copy.
if not exist "%PS_FILE%" (
    echo random_edge_searcher.ps1 is missing - downloading a fresh copy...
    powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%RAW%' -OutFile '%PS_FILE%' -UseBasicParsing -ErrorAction Stop; Write-Host 'Downloaded.' } catch { Write-Host ('Download failed: ' + $_.Exception.Message) }"
    echo.
)

if not exist "%PS_FILE%" (
    echo.
    echo ERROR: random_edge_searcher.ps1 is still not in this folder.
    echo  - Make sure you EXTRACTED the ZIP ^(don't run from inside the zip viewer^).
    echo  - Or check your internet connection so auto-download can fetch it.
    echo.
    pause
    exit /b 1
)

powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File "%PS_FILE%"
echo.
echo Script exited. Press any key to close this window.
pause >nul
