param(
    [int]$TopProcesses = 10,
    [int]$EventLastHours = 24
)

$ErrorActionPreference = "Stop"

Import-Module (Resolve-Path "$PSScriptRoot\..\src\WinAuditPro.psm1") -Force

$audit = New-AuditObject -TopProcesses $TopProcesses -EventLastHours $EventLastHours

$reportDir = Join-Path $PSScriptRoot "..\reports"
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

$jsonPath = Join-Path $reportDir "report.json"
$htmlPath = Join-Path $reportDir "report.html"

$audit | ConvertTo-Json -Depth 6 | Set-Content $jsonPath -Encoding UTF8
ConvertTo-AuditHtml -AuditObject $audit | Set-Content $htmlPath -Encoding UTF8

Write-Host "Saved:"
Write-Host " - $jsonPath"
Write-Host " - $htmlPath"
