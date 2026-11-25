<#
  plug.ps1 - the switch, one word.

    .\plug.ps1 kill "reason"     kill every running copy and every launch
    .\plug.ps1 alive             let them back in
    .\plug.ps1 status            show what the repo currently says

  Writes status.json, commits, pushes. Git uses the credential already in
  Windows Credential Manager; nothing is stored here.

  Measured window: GitHub serves raw with max-age=300, so a running copy can
  take up to five minutes to notice. Launches are refused once the edge
  expires the path.
#>

param(
    [Parameter(Position = 0)][ValidateSet("kill", "alive", "status")][string]$Action = "status",
    [Parameter(Position = 1)][string]$Reason = "shut down"
)

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

function Read-State {
    if (-not (Test-Path "status.json")) { return [pscustomobject]@{ kill = $false; reason = "" } }
    $raw = Get-Content -LiteralPath "status.json" -Raw | ConvertFrom-Json
    return [pscustomobject]@{ kill = [bool]$raw.kill; reason = [string]$raw.reason }
}

if ($Action -eq "status") {
    $s = Read-State
    "kill   : $($s.kill)"
    "reason : $($s.reason)"
    exit 0
}

$kill = $Action -eq "kill"
$reasonText = if ($kill) { $Reason } else { "" }

$json = "{`n  `"kill`": $($kill.ToString().ToLower()),`n  `"reason`": `"$reasonText`"`n}`n"
[IO.File]::WriteAllText((Join-Path $PSScriptRoot "status.json"), $json)

$msg = if ($kill) { "plug pulled: $reasonText" } else { "plug back in" }
git add status.json
git commit -m $msg | Out-Null
git push origin main 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    "push failed - the file is written, run: git push origin main"
    exit 1
}

"$Action done. Edge window: up to 5 minutes."
