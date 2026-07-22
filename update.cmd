@echo off
rem Manueller Fallback: State einspielen, verschluesseln, pushen (fragt nichts ab, nutzt Credential Manager).
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  ". '%~dp0credman.ps1'; $pw=[TrCredMan]::Read('felder-marktmonitor-passwort'); if(-not $pw){ Write-Error 'Kein Passwort hinterlegt (setup-passwort.cmd)'; exit 1 }; " ^
  "$env:Path=[Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User'); " ^
  "python '%~dp0inject_state.py' '%~dp0.'; if($LASTEXITCODE){exit 1}; " ^
  "python '%~dp0encrypt_page.py' '%~dp0marktmonitor.html' '%~dp0index.html' $pw; if($LASTEXITCODE){exit 1}; " ^
  "python '%~dp0encrypt_page.py' '%~dp0marktmonitor-state.json' '%~dp0backup\state.enc' $pw; if($LASTEXITCODE){exit 1}; " ^
  "git add index.html backup/state.enc; git commit -m ('Markt-Monitor manuelles Update ' + (Get-Date -Format 'dd.MM.yyyy')); git push"
pause
