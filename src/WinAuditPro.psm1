Set-StrictMode -Version Latest

function Get-SystemSummary {
    [CmdletBinding()]
    param()

    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1

    [pscustomobject]@{
        ComputerName      = $env:COMPUTERNAME
        UserName          = $env:USERNAME
        OS                = $os.Caption
        OSVersion         = $os.Version
        BuildNumber       = $os.BuildNumber
        InstallDate       = $os.InstallDate
        LastBootUpTime    = $os.LastBootUpTime
        Manufacturer      = $cs.Manufacturer
        Model             = $cs.Model
        CPU               = $cpu.Name
        Cores             = $cpu.NumberOfCores
        LogicalProcessors = $cpu.NumberOfLogicalProcessors
        TotalRAMGB        = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    }
}

function Get-DiskSummary {
    [CmdletBinding()]
    param()

    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" |
        Select-Object DeviceID,
            @{n="SizeGB"; e={[math]::Round($_.Size/1GB,2)}},
            @{n="FreeGB"; e={[math]::Round($_.FreeSpace/1GB,2)}},
            @{n="FreePct"; e={ if ($_.Size -gt 0) {[math]::Round(($_.FreeSpace/$_.Size)*100,1)} else {0} }}
}

function Get-TopProcesses {
    [CmdletBinding()]
    param(
        [int]$Top = 10
    )

    $procs = Get-Process | ForEach-Object {
        [pscustomobject]@{
            Name   = $_.ProcessName
            Id     = $_.Id
            CPU    = $_.CPU
            RAMMB  = [math]::Round($_.WorkingSet64 / 1MB, 1)
        }
    }

    [pscustomobject]@{
        TopCPU = $procs | Sort-Object CPU -Descending | Select-Object -First $Top
        TopRAM = $procs | Sort-Object RAMMB -Descending | Select-Object -First $Top
    }
}

function Get-NetworkSummary {
    [CmdletBinding()]
    param()

    $ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "169.254*" -and $_.InterfaceAlias -notlike "*Loopback*" } |
        Select-Object InterfaceAlias, IPAddress, PrefixLength

    $dns = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Select-Object InterfaceAlias, ServerAddresses

    [pscustomobject]@{
        IPAddresses = $ips
        DNSServers  = $dns
    }
}

function Get-SecuritySummary {
    [CmdletBinding()]
    param()

    $fw = Get-NetFirewallProfile -ErrorAction SilentlyContinue |
        Select-Object Name, Enabled

    $defender = $null
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        $defender = [pscustomobject]@{
            RealTimeProtectionEnabled = $mp.RealTimeProtectionEnabled
            AntivirusEnabled         = $mp.AntivirusEnabled
            AMServiceEnabled         = $mp.AMServiceEnabled
            NISEnabled               = $mp.NISEnabled
            QuickScanAgeDays         = $mp.QuickScanAge
            FullScanAgeDays          = $mp.FullScanAge
            AntivirusSignatureAge    = $mp.AntivirusSignatureAge
        }
    } catch {
        $defender = [pscustomobject]@{ Note = "Defender status unavailable (requires Defender / permissions)." }
    }

    [pscustomobject]@{
        FirewallProfiles = $fw
        Defender         = $defender
    }
}

function Get-EventErrors {
    [CmdletBinding()]
    param(
        [int]$LastHours = 24,
        [int]$MaxEvents = 50
    )

    $since = (Get-Date).AddHours(-1 * $LastHours)
    Get-WinEvent -FilterHashtable @{LogName='System'; Level=2; StartTime=$since} -ErrorAction SilentlyContinue |
        Select-Object -First $MaxEvents TimeCreated, ProviderName, Id, Message
}

function New-AuditObject {
    [CmdletBinding()]
    param(
        [int]$TopProcesses = 10,
        [int]$EventLastHours = 24
    )

    [pscustomobject]@{
        GeneratedAt    = Get-Date
        System         = Get-SystemSummary
        Disks          = Get-DiskSummary
        Processes      = Get-TopProcesses -Top $TopProcesses
        Network        = Get-NetworkSummary
        Security       = Get-SecuritySummary
        SystemErrors   = Get-EventErrors -LastHours $EventLastHours
    }
}

function ConvertTo-AuditHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $AuditObject,
        [string]$Title = "WinAudit-Pro Report"
    )

    $css = @"
body { font-family: Segoe UI, Arial; margin: 24px; background: #0b0f14; color: #e6edf3; }
h1,h2 { color: #58a6ff; }
.card { background: #111826; border: 1px solid #1f2a3a; border-radius: 10px; padding: 16px; margin: 12px 0; }
table { width: 100%; border-collapse: collapse; margin-top: 10px; }
th, td { border-bottom: 1px solid #1f2a3a; padding: 8px; text-align: left; }
.small { color: #9fb1c5; font-size: 12px; }
.badge { display:inline-block; padding:2px 8px; border-radius: 999px; background:#1f6feb; color:white; font-size:12px; }
"@

    $sys = $AuditObject.System | ConvertTo-Html -Fragment -As List
    $disks = $AuditObject.Disks | ConvertTo-Html -Fragment
    $topCPU = $AuditObject.Processes.TopCPU | ConvertTo-Html -Fragment
    $topRAM = $AuditObject.Processes.TopRAM | ConvertTo-Html -Fragment
    $fw = $AuditObject.Security.FirewallProfiles | ConvertTo-Html -Fragment
    $errs = $AuditObject.SystemErrors | ConvertTo-Html -Fragment

    @"
<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>$Title</title>
<style>$css</style>
</head>
<body>
  <h1>$Title <span class="badge">$($AuditObject.GeneratedAt)</span></h1>
  <div class="small">Generated by WinAudit-Pro (PowerShell). Share this repo with recruiters to showcase automation + reporting.</div>

  <div class="card">
    <h2>System Summary</h2>
    $sys
  </div>

  <div class="card">
    <h2>Disk Summary</h2>
    $disks
  </div>

  <div class="card">
    <h2>Top Processes (CPU)</h2>
    $topCPU
    <h2>Top Processes (RAM)</h2>
    $topRAM
  </div>

  <div class="card">
    <h2>Security</h2>
    <h3>Firewall Profiles</h3>
    $fw
    <h3>Defender</h3>
    <pre>$($AuditObject.Security.Defender | ConvertTo-Json -Depth 5)</pre>
  </div>

  <div class="card">
    <h2>System Errors (last 24h)</h2>
    $errs
  </div>
</body>
</html>
"@
}

Export-ModuleMember -Function `
    Get-SystemSummary, Get-DiskSummary, Get-TopProcesses, Get-NetworkSummary, Get-SecuritySummary, Get-EventErrors, `
    New-AuditObject, ConvertTo-AuditHtml
