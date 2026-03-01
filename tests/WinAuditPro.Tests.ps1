Import-Module (Resolve-Path "$PSScriptRoot\..\src\WinAuditPro.psm1") -Force

Describe "WinAudit-Pro" {
    It "Creates an audit object" {
        $a = New-AuditObject
        $a | Should -Not -BeNullOrEmpty
    }

    It "System summary has fields" {
        $s = Get-SystemSummary
        $s.ComputerName | Should -Not -BeNullOrEmpty
        $s.OS | Should -Not -BeNullOrEmpty
    }

    It "HTML output contains key sections" {
        $a = New-AuditObject
        $html = ConvertTo-AuditHtml -AuditObject $a
        $html | Should -Match "System Summary"
        $html | Should -Match "Disk Summary"
        $html | Should -Match "Security"
    }
}
