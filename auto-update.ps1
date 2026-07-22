# FELDER Markt-Monitor Auto-Update: Recherche (Claude CLI) -> State einspielen -> verschluesseln -> pushen -> Backup.
# Windows-Taskplaner:  Mo 08:15 -Mode voll  |  Do 08:15 -Mode news
param([ValidateSet("voll", "news")][string]$Mode = "voll")

$ErrorActionPreference = "Stop"
$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $RepoDir
New-Item -ItemType Directory -Force "$RepoDir\logs" | Out-Null
New-Item -ItemType Directory -Force "$RepoDir\backup" | Out-Null
$Log = "$RepoDir\logs\auto-update.log"

function Say($msg, $lvl) {
    if ($null -eq $lvl) { $lvl = "INFO" }
    $line = "{0} [{1}] [{2}] {3}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $lvl, $Mode, $msg
    Add-Content -Path $Log -Value $line -Encoding utf8
    Write-Host $line
}

try {
    Say "=== Lauf gestartet ==="

    $Claude = "$env:USERPROFILE\.local\bin\claude.exe"
    if (-not (Test-Path $Claude)) { throw "claude.exe nicht gefunden: $Claude" }
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    $Python = (Get-Command python -ErrorAction Stop).Source
    Say "claude: $Claude | python: $Python"

    # Passwort zuerst - ohne Passwort gar nicht erst recherchieren
    . "$RepoDir\credman.ps1"
    $PW = [TrCredMan]::Read("felder-marktmonitor-passwort")
    if ([string]::IsNullOrEmpty($PW)) { throw "Kein Passwort im Credential Manager (setup-passwort.cmd ausfuehren!)" }

    git pull --quiet 2>$null
    $hashVor = (Get-FileHash "$RepoDir\marktmonitor-state.json" -Algorithm SHA256).Hash

    # Recherche-Lauf (unbeaufsichtigt; Claude editiert NUR marktmonitor-state.json und feldnotizen.md)
    $promptDatei = if ($Mode -eq "voll") { "monitor-auftrag-voll.md" } else { "monitor-auftrag-news.md" }
    $prompt = Get-Content "$RepoDir\$promptDatei" -Raw -Encoding UTF8
    Say "Starte Claude-Recherche ($promptDatei) ..."
    $prompt | & $Claude -p --allowedTools "WebSearch,WebFetch,Read,Write,Edit,Glob,Grep" --permission-mode acceptEdits --max-turns 150 | Out-File "$RepoDir\logs\claude-output.txt" -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw "Claude-Lauf fehlgeschlagen (Exit $LASTEXITCODE) - siehe logs\claude-output.txt" }

    $hashNach = (Get-FileHash "$RepoDir\marktmonitor-state.json" -Algorithm SHA256).Hash
    $geaendert = ($hashVor -ne $hashNach)

    if ($Mode -eq "news" -and -not $geaendert) {
        Say "News-Lauf ohne neue Ereignisse - nichts zu veroeffentlichen. Fertig."
        exit 0
    }
    if ($Mode -eq "voll" -and -not $geaendert) {
        throw "Voll-Lauf hat marktmonitor-state.json nicht veraendert - Recherche vermutlich fehlgeschlagen. Nichts veroeffentlicht."
    }

    # Plausibilitaet: State muss valides JSON mit Pflichtschluesseln sein (inject_state.py prueft), Mindestgroesse
    $stateRaw = Get-Content "$RepoDir\marktmonitor-state.json" -Raw -Encoding UTF8
    if ($stateRaw.Length -lt 8000) { throw "State verdaechtig klein ($($stateRaw.Length) Zeichen) - nichts veroeffentlicht." }

    # State in HTML einspielen (validiert JSON + Pflichtschluessel)
    & $Python "$RepoDir\inject_state.py" "$RepoDir"
    if ($LASTEXITCODE -ne 0) { throw "inject_state.py fehlgeschlagen (Exit $LASTEXITCODE)" }

    # Verschluesseln: Dashboard (index.html) + State-Backup (backup/state.enc)
    & $Python "$RepoDir\encrypt_page.py" "$RepoDir\marktmonitor.html" "$RepoDir\index.html" "$PW"
    if ($LASTEXITCODE -ne 0) { throw "Verschluesselung Dashboard fehlgeschlagen (Exit $LASTEXITCODE)" }
    & $Python "$RepoDir\encrypt_page.py" "$RepoDir\marktmonitor-state.json" "$RepoDir\backup\state.enc" "$PW"
    if ($LASTEXITCODE -ne 0) { throw "Verschluesselung Backup fehlgeschlagen (Exit $LASTEXITCODE)" }

    # Zweite lokale Sicherung (Wiederherstellung ohne Netz)
    Copy-Item "$RepoDir\marktmonitor-state.json" "$RepoDir\backup\state-letzter-guter-stand.json" -Force

    git add index.html backup/state.enc
    git commit -m "Markt-Monitor Auto-Update ($Mode) $(Get-Date -Format 'dd.MM.yyyy')" --quiet
    git push --quiet
    Say "Veroeffentlicht: https://winklermark.github.io/felder-marktmonitor/"
    Say "=== Lauf erfolgreich beendet ==="
} catch {
    Say "FEHLER: $($_.Exception.Message)" "ERROR"
    exit 1
}
