@echo off
title Dynamic Island Media Bridge
cd /d "%~dp0"
if exist "media_bridge.exe" (
    start "" "media_bridge.exe"
    exit
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0media_bridge.ps1"
pause
