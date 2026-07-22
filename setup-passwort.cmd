@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-passwort.ps1" %*
pause
