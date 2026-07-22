# Legt/erneuert das Markt-Monitor-Passwort im Windows Credential Manager (Target: felder-marktmonitor-passwort).
# Aufruf ohne Parameter: fragt interaktiv ab.  Aufruf -Anzeigen: zeigt das gespeicherte Passwort an.
param([switch]$Anzeigen)
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\credman.ps1"
$Target = "felder-marktmonitor-passwort"
if ($Anzeigen) {
    $pw = [TrCredMan]::Read($Target)
    if ([string]::IsNullOrEmpty($pw)) { Write-Host "Kein Passwort hinterlegt." } else { Write-Host "Passwort: $pw" }
    exit 0
}
$sec = Read-Host "Neues Markt-Monitor-Passwort" -AsSecureString
$pw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
if ([string]::IsNullOrWhiteSpace($pw)) { throw "Leeres Passwort - abgebrochen." }
if (-not [TrCredMan]::Write($Target, $pw)) { throw "Speichern fehlgeschlagen." }
Write-Host "Gespeichert unter '$Target' (nur dieses Windows-Konto)."
