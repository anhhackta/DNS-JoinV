<# : batch script
@echo off
setlocal EnableDelayedExpansion

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -WindowStyle Hidden -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: Run PowerShell hidden with embedded script
powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content '%~f0' -Raw) -split '<#'+'psscript#>')[1]"
exit /b
<#psscript#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================
# DNS JoinV - Simple DNS Management Tool
# Author: @anhhackta
# GitHub: https://github.com/anhhackta
# ============================================

# Language strings
$script:Lang = @{
    EN = @{
        Title = "DNS JoinV"
        Admin = "[Administrator]"
        CurrentStatus = "Current DNS Status"
        NetworkAdapter = "Network Adapter:"
        Refresh = "Refresh"
        SelectDNS = "Select DNS Provider"
        AlsoIPv6 = "Also set IPv6 DNS (Recommended)"
        ApplyDNS = "Apply DNS"
        ResetDHCP = "Reset to Auto (DHCP)"
        PingTest = "Ping Test"
        BenchmarkAll = "Benchmark All"
        FlushCache = "Flush DNS Cache"
        NetworkSettings = "Network Settings"
        SpeedTest = "Speed Test"
        Log = "Log"
        Clear = "Clear"
        Language = "Language"
        Author = "Author: @anhhackta"
        GitHub = "GitHub"
        LogStarted = "DNS JoinV started"
        LogRefreshed = "Refreshed adapter list and status"
        LogApplying = "Applying DNS..."
        LogIPv4Set = "IPv4 DNS set"
        LogIPv6Set = "IPv6 DNS set"
        LogDone = "DNS applied successfully!"
        LogReset = "Resetting DNS to DHCP..."
        LogResetOK = "DNS reset to Automatic (DHCP)"
        LogPinging = "Pinging"
        LogBenchmark = "Benchmarking all DNS servers..."
        LogBest = "BEST"
        LogFlushed = "DNS cache flushed"
        LogSpeedTest = "Running speed test..."
        LogDownloaded = "Downloaded"
        LogSpeed = "Speed"
        LogError = "ERROR"
        LogFailed = "FAILED"
        NoAdapter = "No adapter selected"
    }
    VI = @{
        Title = "DNS JoinV"
        Admin = "[Quan tri vien]"
        CurrentStatus = "Trang Thai DNS Hien Tai"
        NetworkAdapter = "Card Mang:"
        Refresh = "Lam Moi"
        SelectDNS = "Chon Nha Cung Cap DNS"
        AlsoIPv6 = "Thiet lap ca IPv6 (Khuyen nghi)"
        ApplyDNS = "Ap Dung DNS"
        ResetDHCP = "Dat Lai Tu Dong (DHCP)"
        PingTest = "Kiem Tra Ping"
        BenchmarkAll = "Danh Gia Tat Ca"
        FlushCache = "Xoa Cache DNS"
        NetworkSettings = "Cai Dat Mang"
        SpeedTest = "Kiem Tra Toc Do"
        Log = "Nhat Ky"
        Clear = "Xoa"
        Language = "Ngon Ngu"
        Author = "Tac Gia: @anhhackta"
        GitHub = "GitHub"
        LogStarted = "DNS JoinV da khoi dong"
        LogRefreshed = "Da lam moi danh sach va trang thai"
        LogApplying = "Dang ap dung DNS..."
        LogIPv4Set = "Da thiet lap IPv4 DNS"
        LogIPv6Set = "Da thiet lap IPv6 DNS"
        LogDone = "Ap dung DNS thanh cong!"
        LogReset = "Dang dat lai DNS ve DHCP..."
        LogResetOK = "Da dat lai DNS ve Tu dong (DHCP)"
        LogPinging = "Dang ping"
        LogBenchmark = "Dang danh gia tat ca DNS..."
        LogBest = "TOT NHAT"
        LogFlushed = "Da xoa cache DNS"
        LogSpeedTest = "Dang kiem tra toc do..."
        LogDownloaded = "Da tai"
        LogSpeed = "Toc do"
        LogError = "LOI"
        LogFailed = "THAT BAI"
        NoAdapter = "Chua chon card mang"
    }
}

$script:CurrentLang = "EN"

# DNS Presets with IPv4 and IPv6
$script:DNSPresets = [ordered]@{
    "Google DNS" = @{
        IPv4 = @("8.8.8.8", "8.8.4.4")
        IPv6 = @("2001:4860:4860::8888", "2001:4860:4860::8844")
    }
    "Cloudflare" = @{
        IPv4 = @("1.1.1.1", "1.0.0.1")
        IPv6 = @("2606:4700:4700::1111", "2606:4700:4700::1001")
    }
    "OpenDNS" = @{
        IPv4 = @("208.67.222.222", "208.67.220.220")
        IPv6 = @("2620:119:35::35", "2620:119:53::53")
    }
    "AdGuard DNS" = @{
        IPv4 = @("94.140.14.14", "94.140.15.15")
        IPv6 = @("2a10:50c0::ad1:ff", "2a10:50c0::ad2:ff")
    }
    "Quad9" = @{
        IPv4 = @("9.9.9.9", "149.112.112.112")
        IPv6 = @("2620:fe::fe", "2620:fe::9")
    }
    "Quad9 No Security" = @{
        IPv4 = @("9.9.9.10", "149.112.112.10")
        IPv6 = @("2620:fe::10", "2620:fe::fe:10")
    }
    "Orange DNS" = @{
        IPv4 = @("80.10.246.2", "80.10.246.129")
        IPv6 = @($null, $null)
    }
    "Norton DNS" = @{
        IPv4 = @("199.85.126.10", "199.85.127.10")
        IPv6 = @($null, $null)
    }
}

# Get active adapters
function Get-ActiveAdapters {
    return Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.PhysicalMediaType -ne "Unspecified" }
}

# Get current DNS status
function Get-CurrentDNSStatus {
    $adapters = Get-ActiveAdapters
    $results = @()
    foreach ($adapter in $adapters) {
        $ipv4DNS = (Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses
        $ipv6DNS = (Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv6 -ErrorAction SilentlyContinue).ServerAddresses
        $results += @{
            Name = $adapter.Name
            InterfaceIndex = $adapter.ifIndex
            IPv4 = if ($ipv4DNS) { $ipv4DNS -join ", " } else { "DHCP (Auto)" }
            IPv6 = if ($ipv6DNS -and ($ipv6DNS | Where-Object { $_ -notmatch '^fe80|^::1' })) { 
                ($ipv6DNS | Where-Object { $_ -notmatch '^fe80|^::1' }) -join ", " 
            } else { "DHCP (Auto)" }
        }
    }
    return $results
}

# Ping DNS
function Test-DNSPing {
    param([string]$DNS)
    try {
        $ping = Test-Connection -ComputerName $DNS -Count 3 -ErrorAction Stop
        $avg = ($ping | Measure-Object -Property ResponseTime -Average).Average
        return @{ Success = $true; Avg = [math]::Round($avg, 1) }
    } catch {
        return @{ Success = $false; Avg = 0 }
    }
}

# Get text from current language
function T { param([string]$Key) return $script:Lang[$script:CurrentLang][$Key] }

# ============================================
# GUI
# ============================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "DNS JoinV v1.0"
$form.Size = New-Object System.Drawing.Size(680, 650)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(28, 28, 32)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Colors
$accent = [System.Drawing.Color]::FromArgb(0, 180, 120)
$text = [System.Drawing.Color]::White
$panel = [System.Drawing.Color]::FromArgb(40, 40, 48)
$btn = [System.Drawing.Color]::FromArgb(55, 55, 65)

# Title
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "DNS JoinV"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = $accent
$lblTitle.Location = New-Object System.Drawing.Point(20, 10)
$lblTitle.AutoSize = $true
$form.Controls.Add($lblTitle)

$lblAdmin = New-Object System.Windows.Forms.Label
$lblAdmin.Text = "[Administrator]"
$lblAdmin.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblAdmin.ForeColor = [System.Drawing.Color]::LightGreen
$lblAdmin.Location = New-Object System.Drawing.Point(155, 18)
$lblAdmin.AutoSize = $true
$form.Controls.Add($lblAdmin)

# Language selector
$lblLang = New-Object System.Windows.Forms.Label
$lblLang.Text = "Language:"
$lblLang.ForeColor = $text
$lblLang.Location = New-Object System.Drawing.Point(480, 15)
$lblLang.AutoSize = $true
$form.Controls.Add($lblLang)

$cmbLang = New-Object System.Windows.Forms.ComboBox
$cmbLang.Location = New-Object System.Drawing.Point(550, 12)
$cmbLang.Size = New-Object System.Drawing.Size(100, 25)
$cmbLang.DropDownStyle = "DropDownList"
$cmbLang.BackColor = $btn
$cmbLang.ForeColor = $text
$cmbLang.FlatStyle = "Flat"
$cmbLang.Items.Add("English") | Out-Null
$cmbLang.Items.Add("Tieng Viet") | Out-Null
$cmbLang.SelectedIndex = 0
$form.Controls.Add($cmbLang)

# === Current Status Panel ===
$pnlStatus = New-Object System.Windows.Forms.Panel
$pnlStatus.Location = New-Object System.Drawing.Point(20, 45)
$pnlStatus.Size = New-Object System.Drawing.Size(625, 100)
$pnlStatus.BackColor = $panel
$form.Controls.Add($pnlStatus)

$lblStatusTitle = New-Object System.Windows.Forms.Label
$lblStatusTitle.Text = "Current DNS Status"
$lblStatusTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblStatusTitle.ForeColor = $text
$lblStatusTitle.Location = New-Object System.Drawing.Point(10, 8)
$lblStatusTitle.AutoSize = $true
$pnlStatus.Controls.Add($lblStatusTitle)

$txtStatus = New-Object System.Windows.Forms.TextBox
$txtStatus.Location = New-Object System.Drawing.Point(10, 32)
$txtStatus.Size = New-Object System.Drawing.Size(605, 60)
$txtStatus.Multiline = $true
$txtStatus.ReadOnly = $true
$txtStatus.ScrollBars = "Vertical"
$txtStatus.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 30)
$txtStatus.ForeColor = [System.Drawing.Color]::Cyan
$txtStatus.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtStatus.BorderStyle = "FixedSingle"
$pnlStatus.Controls.Add($txtStatus)

# === Adapter Selection ===
$lblAdapter = New-Object System.Windows.Forms.Label
$lblAdapter.Text = "Network Adapter:"
$lblAdapter.ForeColor = $text
$lblAdapter.Location = New-Object System.Drawing.Point(20, 155)
$lblAdapter.AutoSize = $true
$form.Controls.Add($lblAdapter)

$cmbAdapter = New-Object System.Windows.Forms.ComboBox
$cmbAdapter.Location = New-Object System.Drawing.Point(140, 152)
$cmbAdapter.Size = New-Object System.Drawing.Size(300, 25)
$cmbAdapter.DropDownStyle = "DropDownList"
$cmbAdapter.BackColor = $btn
$cmbAdapter.ForeColor = $text
$cmbAdapter.FlatStyle = "Flat"
$form.Controls.Add($cmbAdapter)

$btnRefreshAdapter = New-Object System.Windows.Forms.Button
$btnRefreshAdapter.Text = "Refresh"
$btnRefreshAdapter.Location = New-Object System.Drawing.Point(450, 150)
$btnRefreshAdapter.Size = New-Object System.Drawing.Size(90, 27)
$btnRefreshAdapter.BackColor = $btn
$btnRefreshAdapter.ForeColor = $text
$btnRefreshAdapter.FlatStyle = "Flat"
$btnRefreshAdapter.Cursor = "Hand"
$form.Controls.Add($btnRefreshAdapter)

# === DNS Selection Panel ===
$pnlDNS = New-Object System.Windows.Forms.Panel
$pnlDNS.Location = New-Object System.Drawing.Point(20, 190)
$pnlDNS.Size = New-Object System.Drawing.Size(625, 160)
$pnlDNS.BackColor = $panel
$form.Controls.Add($pnlDNS)

$lblDNSTitle = New-Object System.Windows.Forms.Label
$lblDNSTitle.Text = "Select DNS Provider"
$lblDNSTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblDNSTitle.ForeColor = $text
$lblDNSTitle.Location = New-Object System.Drawing.Point(10, 8)
$lblDNSTitle.AutoSize = $true
$pnlDNS.Controls.Add($lblDNSTitle)

$cmbDNS = New-Object System.Windows.Forms.ComboBox
$cmbDNS.Location = New-Object System.Drawing.Point(10, 35)
$cmbDNS.Size = New-Object System.Drawing.Size(200, 25)
$cmbDNS.DropDownStyle = "DropDownList"
$cmbDNS.BackColor = $btn
$cmbDNS.ForeColor = $text
$cmbDNS.FlatStyle = "Flat"
foreach ($dns in $script:DNSPresets.Keys) { $cmbDNS.Items.Add($dns) | Out-Null }
$cmbDNS.SelectedIndex = 0
$pnlDNS.Controls.Add($cmbDNS)

$lblIPv4Info = New-Object System.Windows.Forms.Label
$lblIPv4Info.Text = "IPv4:"
$lblIPv4Info.ForeColor = [System.Drawing.Color]::LightGray
$lblIPv4Info.Font = New-Object System.Drawing.Font("Consolas", 9)
$lblIPv4Info.Location = New-Object System.Drawing.Point(10, 68)
$lblIPv4Info.Size = New-Object System.Drawing.Size(600, 18)
$pnlDNS.Controls.Add($lblIPv4Info)

$lblIPv6Info = New-Object System.Windows.Forms.Label
$lblIPv6Info.Text = "IPv6:"
$lblIPv6Info.ForeColor = [System.Drawing.Color]::LightGray
$lblIPv6Info.Font = New-Object System.Drawing.Font("Consolas", 9)
$lblIPv6Info.Location = New-Object System.Drawing.Point(10, 88)
$lblIPv6Info.Size = New-Object System.Drawing.Size(600, 18)
$pnlDNS.Controls.Add($lblIPv6Info)

$chkIPv6 = New-Object System.Windows.Forms.CheckBox
$chkIPv6.Text = "Also set IPv6 DNS (Recommended)"
$chkIPv6.ForeColor = $text
$chkIPv6.Location = New-Object System.Drawing.Point(220, 35)
$chkIPv6.Size = New-Object System.Drawing.Size(280, 22)
$chkIPv6.Checked = $true
$pnlDNS.Controls.Add($chkIPv6)

$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "Apply DNS"
$btnApply.Location = New-Object System.Drawing.Point(10, 115)
$btnApply.Size = New-Object System.Drawing.Size(120, 35)
$btnApply.BackColor = [System.Drawing.Color]::FromArgb(0, 140, 90)
$btnApply.ForeColor = $text
$btnApply.FlatStyle = "Flat"
$btnApply.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnApply.Cursor = "Hand"
$pnlDNS.Controls.Add($btnApply)

$btnReset = New-Object System.Windows.Forms.Button
$btnReset.Text = "Reset to DHCP"
$btnReset.Location = New-Object System.Drawing.Point(140, 115)
$btnReset.Size = New-Object System.Drawing.Size(130, 35)
$btnReset.BackColor = [System.Drawing.Color]::FromArgb(180, 80, 0)
$btnReset.ForeColor = $text
$btnReset.FlatStyle = "Flat"
$btnReset.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnReset.Cursor = "Hand"
$pnlDNS.Controls.Add($btnReset)

$btnPing = New-Object System.Windows.Forms.Button
$btnPing.Text = "Ping Test"
$btnPing.Location = New-Object System.Drawing.Point(280, 115)
$btnPing.Size = New-Object System.Drawing.Size(100, 35)
$btnPing.BackColor = $btn
$btnPing.ForeColor = $text
$btnPing.FlatStyle = "Flat"
$btnPing.Cursor = "Hand"
$pnlDNS.Controls.Add($btnPing)

$btnBenchmark = New-Object System.Windows.Forms.Button
$btnBenchmark.Text = "Benchmark All"
$btnBenchmark.Location = New-Object System.Drawing.Point(390, 115)
$btnBenchmark.Size = New-Object System.Drawing.Size(120, 35)
$btnBenchmark.BackColor = [System.Drawing.Color]::FromArgb(80, 50, 120)
$btnBenchmark.ForeColor = $text
$btnBenchmark.FlatStyle = "Flat"
$btnBenchmark.Cursor = "Hand"
$pnlDNS.Controls.Add($btnBenchmark)

# === Tools Panel ===
$pnlTools = New-Object System.Windows.Forms.Panel
$pnlTools.Location = New-Object System.Drawing.Point(20, 360)
$pnlTools.Size = New-Object System.Drawing.Size(625, 45)
$pnlTools.BackColor = $panel
$form.Controls.Add($pnlTools)

$btnFlush = New-Object System.Windows.Forms.Button
$btnFlush.Text = "Flush DNS Cache"
$btnFlush.Location = New-Object System.Drawing.Point(10, 7)
$btnFlush.Size = New-Object System.Drawing.Size(140, 30)
$btnFlush.BackColor = $btn
$btnFlush.ForeColor = $text
$btnFlush.FlatStyle = "Flat"
$btnFlush.Cursor = "Hand"
$pnlTools.Controls.Add($btnFlush)

$btnNetworkSettings = New-Object System.Windows.Forms.Button
$btnNetworkSettings.Text = "Network Settings"
$btnNetworkSettings.Location = New-Object System.Drawing.Point(160, 7)
$btnNetworkSettings.Size = New-Object System.Drawing.Size(140, 30)
$btnNetworkSettings.BackColor = $btn
$btnNetworkSettings.ForeColor = $text
$btnNetworkSettings.FlatStyle = "Flat"
$btnNetworkSettings.Cursor = "Hand"
$pnlTools.Controls.Add($btnNetworkSettings)

$btnSpeedTest = New-Object System.Windows.Forms.Button
$btnSpeedTest.Text = "Speed Test"
$btnSpeedTest.Location = New-Object System.Drawing.Point(310, 7)
$btnSpeedTest.Size = New-Object System.Drawing.Size(120, 30)
$btnSpeedTest.BackColor = [System.Drawing.Color]::FromArgb(50, 100, 150)
$btnSpeedTest.ForeColor = $text
$btnSpeedTest.FlatStyle = "Flat"
$btnSpeedTest.Cursor = "Hand"
$pnlTools.Controls.Add($btnSpeedTest)

# === Log Panel ===
$pnlLog = New-Object System.Windows.Forms.Panel
$pnlLog.Location = New-Object System.Drawing.Point(20, 415)
$pnlLog.Size = New-Object System.Drawing.Size(625, 140)
$pnlLog.BackColor = $panel
$form.Controls.Add($pnlLog)

$lblLogTitle = New-Object System.Windows.Forms.Label
$lblLogTitle.Text = "Log"
$lblLogTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblLogTitle.ForeColor = $text
$lblLogTitle.Location = New-Object System.Drawing.Point(10, 6)
$lblLogTitle.AutoSize = $true
$pnlLog.Controls.Add($lblLogTitle)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Clear"
$btnClear.Location = New-Object System.Drawing.Point(560, 3)
$btnClear.Size = New-Object System.Drawing.Size(55, 22)
$btnClear.BackColor = $btn
$btnClear.ForeColor = $text
$btnClear.FlatStyle = "Flat"
$btnClear.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$btnClear.Cursor = "Hand"
$pnlLog.Controls.Add($btnClear)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(10, 28)
$txtLog.Size = New-Object System.Drawing.Size(605, 105)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.BackColor = [System.Drawing.Color]::FromArgb(22, 22, 26)
$txtLog.ForeColor = [System.Drawing.Color]::LightGreen
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtLog.BorderStyle = "FixedSingle"
$pnlLog.Controls.Add($txtLog)

# === Footer ===
$lblAuthor = New-Object System.Windows.Forms.Label
$lblAuthor.Text = "Author: @anhhackta"
$lblAuthor.ForeColor = [System.Drawing.Color]::Gray
$lblAuthor.Location = New-Object System.Drawing.Point(20, 565)
$lblAuthor.AutoSize = $true
$form.Controls.Add($lblAuthor)

$lnkGitHub = New-Object System.Windows.Forms.LinkLabel
$lnkGitHub.Text = "GitHub"
$lnkGitHub.LinkColor = $accent
$lnkGitHub.Location = New-Object System.Drawing.Point(150, 565)
$lnkGitHub.AutoSize = $true
$form.Controls.Add($lnkGitHub)

# ============================================
# FUNCTIONS
# ============================================

function Log {
    param([string]$Msg)
    $time = Get-Date -Format "HH:mm:ss"
    $txtLog.AppendText("[$time] $Msg`r`n")
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Refresh-Status {
    $adapters = Get-ActiveAdapters
    $cmbAdapter.Items.Clear()
    foreach ($adapter in $adapters) { $cmbAdapter.Items.Add($adapter.Name) | Out-Null }
    if ($cmbAdapter.Items.Count -gt 0) { $cmbAdapter.SelectedIndex = 0 }
    
    $status = Get-CurrentDNSStatus
    $txtStatus.Clear()
    foreach ($s in $status) {
        $txtStatus.AppendText("$($s.Name):`r`n")
        $txtStatus.AppendText("  IPv4: $($s.IPv4)`r`n")
        $txtStatus.AppendText("  IPv6: $($s.IPv6)`r`n")
    }
}

function Update-DNSInfo {
    $selected = $cmbDNS.SelectedItem
    if ($selected -and $script:DNSPresets.Contains($selected)) {
        $dns = $script:DNSPresets[$selected]
        $lblIPv4Info.Text = "IPv4: $($dns.IPv4[0]) | $($dns.IPv4[1])"
        if ($dns.IPv6[0]) {
            $lblIPv6Info.Text = "IPv6: $($dns.IPv6[0])"
            $chkIPv6.Enabled = $true
        } else {
            $lblIPv6Info.Text = "IPv6: Not available"
            $chkIPv6.Enabled = $false
        }
    }
}

function Get-SelectedAdapterIndex {
    $name = $cmbAdapter.SelectedItem
    if ($name) {
        $adapter = Get-NetAdapter | Where-Object { $_.Name -eq $name }
        return $adapter.ifIndex
    }
    return $null
}

function Update-Language {
    $lblAdmin.Text = T "Admin"
    $lblStatusTitle.Text = T "CurrentStatus"
    $lblAdapter.Text = T "NetworkAdapter"
    $btnRefreshAdapter.Text = T "Refresh"
    $lblDNSTitle.Text = T "SelectDNS"
    $chkIPv6.Text = T "AlsoIPv6"
    $btnApply.Text = T "ApplyDNS"
    $btnReset.Text = T "ResetDHCP"
    $btnPing.Text = T "PingTest"
    $btnBenchmark.Text = T "BenchmarkAll"
    $btnFlush.Text = T "FlushCache"
    $btnNetworkSettings.Text = T "NetworkSettings"
    $btnSpeedTest.Text = T "SpeedTest"
    $lblLogTitle.Text = T "Log"
    $btnClear.Text = T "Clear"
    $lblAuthor.Text = T "Author"
}

# ============================================
# EVENTS
# ============================================

$cmbLang.Add_SelectedIndexChanged({
    $script:CurrentLang = if ($cmbLang.SelectedIndex -eq 0) { "EN" } else { "VI" }
    Update-Language
})

$cmbDNS.Add_SelectedIndexChanged({ Update-DNSInfo })

$btnRefreshAdapter.Add_Click({
    Refresh-Status
    Log "[OK] $(T 'LogRefreshed')"
})

$btnApply.Add_Click({
    $ifIndex = Get-SelectedAdapterIndex
    if (-not $ifIndex) { Log "[$(T 'LogError')] $(T 'NoAdapter')"; return }
    
    $selected = $cmbDNS.SelectedItem
    $dns = $script:DNSPresets[$selected]
    
    Log "$(T 'LogApplying') $selected..."
    Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $dns.IPv4 -ErrorAction SilentlyContinue
    Log "[OK] $(T 'LogIPv4Set'): $($dns.IPv4 -join ', ')"
    
    if ($chkIPv6.Checked -and $dns.IPv6[0]) {
        Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ServerAddresses $dns.IPv6 -ErrorAction SilentlyContinue
        Log "[OK] $(T 'LogIPv6Set'): $($dns.IPv6 -join ', ')"
    }
    
    Clear-DnsClientCache
    Refresh-Status
    Log "[OK] $(T 'LogDone')"
})

$btnReset.Add_Click({
    $ifIndex = Get-SelectedAdapterIndex
    if (-not $ifIndex) { Log "[$(T 'LogError')] $(T 'NoAdapter')"; return }
    
    Log "$(T 'LogReset')"
    Set-DnsClientServerAddress -InterfaceIndex $ifIndex -ResetServerAddresses
    Clear-DnsClientCache
    Refresh-Status
    Log "[OK] $(T 'LogResetOK')"
})

$btnPing.Add_Click({
    $selected = $cmbDNS.SelectedItem
    $dns = $script:DNSPresets[$selected]
    Log "$(T 'LogPinging') $selected..."
    $result = Test-DNSPing -DNS $dns.IPv4[0]
    if ($result.Success) { Log "[OK] $selected - $($result.Avg) ms" }
    else { Log "[$(T 'LogFailed')] $selected" }
})

$btnBenchmark.Add_Click({
    Log "$(T 'LogBenchmark')"
    Log ("-" * 45)
    $results = @()
    foreach ($preset in $script:DNSPresets.GetEnumerator()) {
        $r = Test-DNSPing -DNS $preset.Value.IPv4[0]
        if ($r.Success) {
            $results += @{ Name = $preset.Key; Avg = $r.Avg }
            Log "$($preset.Key.PadRight(20)) $($r.Avg) ms"
        } else { Log "$($preset.Key.PadRight(20)) $(T 'LogFailed')" }
    }
    Log ("-" * 45)
    if ($results.Count -gt 0) {
        $best = $results | Sort-Object Avg | Select-Object -First 1
        Log "[$(T 'LogBest')] $($best.Name) - $($best.Avg) ms"
    }
})

$btnFlush.Add_Click({ Clear-DnsClientCache; Log "[OK] $(T 'LogFlushed')" })

$btnNetworkSettings.Add_Click({ Start-Process "ncpa.cpl" })

$btnSpeedTest.Add_Click({
    Log "$(T 'LogSpeedTest')"
    try {
        $url = "https://speed.cloudflare.com/__down?bytes=10000000"
        $web = New-Object System.Net.WebClient
        $start = Get-Date
        $data = $web.DownloadData($url)
        $end = Get-Date
        $sec = ($end - $start).TotalSeconds
        $mb = $data.Length / 1MB
        $mbps = ($data.Length * 8) / ($sec * 1000000)
        Log "[OK] $(T 'LogDownloaded') $([math]::Round($mb,2)) MB in $([math]::Round($sec,2))s"
        Log "[$(T 'LogSpeed')] $([math]::Round($mbps,2)) Mbps"
    } catch { Log "[$(T 'LogError')] Speed test failed" }
})

$btnClear.Add_Click({ $txtLog.Clear() })

$lnkGitHub.Add_Click({ Start-Process "https://github.com/anhhackta" })

# ============================================
# INIT
# ============================================

Refresh-Status
Update-DNSInfo
Update-Language
Log "$(T 'LogStarted')"

[System.Windows.Forms.Application]::Run($form)

#>
