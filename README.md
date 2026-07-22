# felder-marktmonitor

Passwortgeschütztes Wettbewerbs-Dashboard (statisch, clientseitig entschlüsselt). Dieses Repo enthält **nur verschlüsselte Artefakte** (`index.html`, `backup/state.enc`) — Klartext (`marktmonitor.html`, `marktmonitor-state.json`, `feldnotizen.md`, Logs) bleibt per `.gitignore` lokal.

- Live: https://winklermark.github.io/felder-marktmonitor/ (Repo in der Organisation `winklermark`)
- Automatik: Windows-Taskplaner → `auto-update.ps1` (Mo 08:15 `-Mode voll`, Do 08:15 `-Mode news`)
- Manueller Fallback: `update.cmd`
- Passwort: Windows Credential Manager, Target `felder-marktmonitor-passwort` (`setup-passwort.cmd`, Anzeige: `powershell -File setup-passwort.ps1 -Anzeigen`)
- Betriebshandbuch: `..\phase-08-technik.md` im lokalen Projektordner
