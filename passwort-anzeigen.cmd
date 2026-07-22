@echo off
rem Zeigt das Markt-Monitor-Passwort aus dem Windows Credential Manager an (nur auf diesem PC / diesem Windows-Konto).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-passwort.ps1" -Anzeigen
pause
