param(
    [int]$TopProcesses = 10,
    [int]$EventLastHours = 24,
    [string]$OutputPath = (Join-Path $PSScriptRoot "..\reports"),
    [switch]$OpenReport,
    [switch]$Redact
)

$ErrorActionPreference = "Stop"

$moduleManifest = Join-Path $PSScriptRoot "..\src\WinAuditPro.psd1"
$moduleFile     = Join-Path $PSScriptRoot "..\src\WinAuditPro.psm1"

if (Test-Path $moduleManifest) {
    try { Import-Module (Resolve-Path $moduleManifest) -Force -ErrorAction Stop }
    catch { Import-Module (Resolve-Path $moduleFile) -Force }
} else {
    Import-Module (Resolve-Path $moduleFile) -Force
}

$audit = New-AuditObject -TopProcesses $TopProcesses -EventLastHours $EventLastHours

if ($Redact) {
    $audit = Protect-AuditObject -AuditObject $audit
}

New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

$jsonPath = Join-Path $OutputPath "report.json"
$htmlPath = Join-Path $OutputPath "report.html"
$csvPath  = Join-Path $OutputPath "disks.csv"

$audit | ConvertTo-Json -Depth 6 | Set-Content $jsonPath -Encoding UTF8
ConvertTo-AuditHtml -AuditObject $audit | Set-Content $htmlPath -Encoding UTF8
$audit.Disks | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $csvPath

Write-Host "Saved:"
Write-Host " - $jsonPath"
Write-Host " - $htmlPath"
Write-Host " - $csvPath"

if ($OpenReport) { Start-Process $htmlPath }

