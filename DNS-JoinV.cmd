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
# DNS JoinV v1.3 - Simple DNS Management Tool
# Author: @anhhackta
# ============================================

#region Language & Settings
$script:Lang = @{
    EN = @{
        Title = "DNS JoinV"; Admin = "[Administrator]"; CurrentStatus = "Current DNS Status"
        NetworkAdapter = "Network Adapter:"; Refresh = "Refresh"; SelectDNS = "Select DNS Provider"
        AlsoIPv6 = "IPv6"; ApplyDNS = "Apply DNS"; ResetDHCP = "Reset DHCP"; PingTest = "Ping"
        BenchmarkAll = "Benchmark"; FlushCache = "Flush DNS"; NetworkSettings = "Network"
        SpeedTest = "Speed Test"; Log = "Log"; Clear = "Clear"; Author = "Author: @anhhackta"
        LogStarted = "DNS JoinV started"; LogRefreshed = "Refreshed adapter list"
        LogApplying = "Applying DNS..."; LogIPv4Set = "IPv4 DNS set"; LogIPv6Set = "IPv6 DNS set"
        LogDone = "DNS applied!"; LogReset = "Resetting to DHCP..."; LogResetOK = "Reset to DHCP"
        LogPinging = "Pinging"; LogBenchmark = "Benchmarking"; LogBest = "BEST"
        LogFlushed = "DNS cache flushed"; LogSpeedTest = "Testing speed..."
        LogDownloaded = "Downloaded"; LogSpeed = "Speed"; LogError = "ERROR"; LogFailed = "FAILED"
        NoAdapter = "No adapter"; Internet = "Internet"; NoInternet = "No Internet"
    }
    VI = @{
        Title = "DNS JoinV"; Admin = "[Quan Tri]"; CurrentStatus = "Trang Thai DNS"
        NetworkAdapter = "Card Mang:"; Refresh = "Lam Moi"; SelectDNS = "Chon DNS"
        AlsoIPv6 = "IPv6"; ApplyDNS = "Ap Dung"; ResetDHCP = "DHCP"; PingTest = "Ping"
        BenchmarkAll = "Danh Gia"; FlushCache = "Xoa Cache"; NetworkSettings = "Mang"
        SpeedTest = "Toc Do"; Log = "Nhat Ky"; Clear = "Xoa"; Author = "Tac Gia: @anhhackta"
        LogStarted = "Da khoi dong"; LogRefreshed = "Da lam moi"; LogApplying = "Dang ap dung..."
        LogIPv4Set = "Da set IPv4"; LogIPv6Set = "Da set IPv6"; LogDone = "Thanh cong!"
        LogReset = "Dang reset..."; LogResetOK = "Da reset"; LogPinging = "Dang ping"
        LogBenchmark = "Dang danh gia"; LogBest = "TOT NHAT"; LogFlushed = "Da xoa cache"
        LogSpeedTest = "Dang kiem tra..."; LogDownloaded = "Da tai"; LogSpeed = "Toc do"
        LogError = "LOI"; LogFailed = "THAT BAI"; NoAdapter = "Chua chon"
        Internet = "Internet"; NoInternet = "Khong co mang"
    }
}
$script:CurrentLang = "EN"
$script:IsDarkTheme = $true
#endregion

#region DNS Presets
$script:DNSPresets = [ordered]@{
    "Google DNS" = @{ IPv4 = @("8.8.8.8", "8.8.4.4"); IPv6 = @("2001:4860:4860::8888", "2001:4860:4860::8844") }
    "Cloudflare" = @{ IPv4 = @("1.1.1.1", "1.0.0.1"); IPv6 = @("2606:4700:4700::1111", "2606:4700:4700::1001") }
    "OpenDNS" = @{ IPv4 = @("208.67.222.222", "208.67.220.220"); IPv6 = @("2620:119:35::35", "2620:119:53::53") }
    "AdGuard DNS" = @{ IPv4 = @("94.140.14.14", "94.140.15.15"); IPv6 = @("2a10:50c0::ad1:ff", "2a10:50c0::ad2:ff") }
    "Quad9" = @{ IPv4 = @("9.9.9.9", "149.112.112.112"); IPv6 = @("2620:fe::fe", "2620:fe::9") }
    "Quad9 NoSec" = @{ IPv4 = @("9.9.9.10", "149.112.112.10"); IPv6 = @("2620:fe::10", $null) }
    "Verisign" = @{ IPv4 = @("64.6.64.6", "64.6.65.6"); IPv6 = @("2620:74:1b::1:1", $null) }
    "Control D" = @{ IPv4 = @("76.76.2.2", "76.76.10.2"); IPv6 = @("2606:1a40::2", "2606:1a40:1::2") }
    "NextDNS" = @{ IPv4 = @("45.90.28.217", "45.90.30.217"); IPv6 = @($null, $null) }
}
#endregion

#region Helper Functions
function T { param([string]$K) return $script:Lang[$script:CurrentLang][$K] }

function Get-ActiveAdapters {
    Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.PhysicalMediaType -ne "Unspecified" }
}

function Get-CurrentDNSStatus {
    $results = @()
    foreach ($a in (Get-ActiveAdapters)) {
        $v4 = (Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -EA 0).ServerAddresses
        $v6 = (Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv6 -EA 0).ServerAddresses | Where-Object { $_ -notmatch '^fe80|^::1' }
        $results += @{ Name=$a.Name; Index=$a.ifIndex; IPv4=($v4 -join ", "); IPv6=($v6 -join ", ") }
    }
    return $results
}

function Test-DNSPing {
    param([string]$DNS)
    try {
        $result = Test-Connection -ComputerName $DNS -Count 2 -EA SilentlyContinue
        if($result){
            $avg = [math]::Round(($result | Measure-Object -Property ResponseTime -Average).Average, 1)
            return @{Success=$true; Avg=$avg}
        }
        return @{Success=$false; Avg=9999}
    } catch { return @{Success=$false; Avg=9999} }
}

function Test-DNSLatency {
    param([string]$Server)
    try {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $null = Resolve-DnsName -Name "google.com" -Server $Server -Type A -DnsOnly -EA Stop
        $sw.Stop()
        return @{Success=$true; Latency=$sw.ElapsedMilliseconds}
    } catch { return @{Success=$false; Latency=9999} }
}

function Get-DNSProviderName {
    param([string]$IP)
    if(!$IP){ return "DHCP" }
    foreach($p in $script:DNSPresets.GetEnumerator()){ if($p.Value.IPv4 -contains $IP){ return $p.Key } }
    return "Custom"
}

function Test-InternetConnection {
    try {
        $p = New-Object System.Net.NetworkInformation.Ping
        $r = $p.Send("8.8.8.8", 2000)
        $p.Dispose()
        return ($r.Status -eq 'Success')
    } catch { return $false }
}
#endregion

#region Theme Colors
$script:Dark = @{
    Form=[Drawing.Color]::FromArgb(28,28,32); Panel=[Drawing.Color]::FromArgb(40,40,48)
    Btn=[Drawing.Color]::FromArgb(55,55,65); Text=[Drawing.Color]::White
    Accent=[Drawing.Color]::FromArgb(0,180,120); LogBg=[Drawing.Color]::FromArgb(22,22,26)
    LogText=[Drawing.Color]::LightGreen; Status=[Drawing.Color]::Cyan
}
$script:Light = @{
    Form=[Drawing.Color]::FromArgb(245,245,250); Panel=[Drawing.Color]::FromArgb(230,230,235)
    Btn=[Drawing.Color]::FromArgb(210,210,220); Text=[Drawing.Color]::FromArgb(30,30,40)
    Accent=[Drawing.Color]::FromArgb(0,140,90); LogBg=[Drawing.Color]::White
    LogText=[Drawing.Color]::FromArgb(0,100,50); Status=[Drawing.Color]::FromArgb(0,80,120)
}
function GetTheme { if($script:IsDarkTheme){$script:Dark}else{$script:Light} }
#endregion

#region Create Form
$form = New-Object Windows.Forms.Form
$form.Text = "DNS JoinV v1.3"
$form.Size = New-Object Drawing.Size(680,680)
$form.MinimumSize = New-Object Drawing.Size(680,600)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "Sizable"
$form.BackColor = $script:Dark.Form
$form.Font = New-Object Drawing.Font("Segoe UI",9)

# Icon - create a simple DNS icon using GDI+
try {
    $bmp = New-Object Drawing.Bitmap(32,32)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = "AntiAlias"
    $g.Clear([Drawing.Color]::FromArgb(28,28,32))
    # Draw DNS circle
    $brush = New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(0,180,120))
    $g.FillEllipse($brush,4,4,24,24)
    # Draw "D" letter
    $font = New-Object Drawing.Font("Segoe UI",12,[Drawing.FontStyle]::Bold)
    $g.DrawString("D",$font,[Drawing.Brushes]::White,(New-Object Drawing.PointF(8,5)))
    $g.Dispose()
    $handle = $bmp.GetHicon()
    $form.Icon = [Drawing.Icon]::FromHandle($handle)
} catch {}
#endregion

#region Header
$lblTitle = New-Object Windows.Forms.Label
$lblTitle.Text = "DNS JoinV"
$lblTitle.Font = New-Object Drawing.Font("Segoe UI",18,[Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = $script:Dark.Accent
$lblTitle.Location = New-Object Drawing.Point(20,8)
$lblTitle.AutoSize = $true
$form.Controls.Add($lblTitle)

$lblAdmin = New-Object Windows.Forms.Label
$lblAdmin.Text = "[Administrator]"
$lblAdmin.ForeColor = [Drawing.Color]::LightGreen
$lblAdmin.Location = New-Object Drawing.Point(155,16)
$lblAdmin.AutoSize = $true
$form.Controls.Add($lblAdmin)

# Theme Button - borderless icon only (anchor right)
$btnTheme = New-Object Windows.Forms.Button
$btnTheme.Text = [char]0x0052  # R in Wingdings = sun-like
$btnTheme.Font = New-Object Drawing.Font("Wingdings",14)
$btnTheme.Size = New-Object Drawing.Size(32,28)
$btnTheme.Location = New-Object Drawing.Point(560,8)
$btnTheme.BackColor = $script:Dark.Form
$btnTheme.ForeColor = [Drawing.Color]::Gold
$btnTheme.FlatStyle = "Flat"
$btnTheme.FlatAppearance.BorderSize = 0
$btnTheme.Cursor = "Hand"
$btnTheme.Anchor = "Top,Right"
$form.Controls.Add($btnTheme)

# Language (aligned with Refresh button right edge)
$cmbLang = New-Object Windows.Forms.ComboBox
$cmbLang.Location = New-Object Drawing.Point(595,8)
$cmbLang.Size = New-Object Drawing.Size(50,25)
$cmbLang.DropDownStyle = "DropDownList"
$cmbLang.BackColor = $script:Dark.Btn
$cmbLang.ForeColor = $script:Dark.Text
$cmbLang.FlatStyle = "Flat"
$cmbLang.Items.AddRange(@("EN","VI"))
$cmbLang.SelectedIndex = 0
$cmbLang.Anchor = "Top,Right"
$form.Controls.Add($cmbLang)
#endregion

#region Status Panel
$pnlStatus = New-Object Windows.Forms.Panel
$pnlStatus.Location = New-Object Drawing.Point(20,45)
$pnlStatus.Size = New-Object Drawing.Size(625,85)
$pnlStatus.BackColor = $script:Dark.Panel
$pnlStatus.Anchor = "Top,Left,Right"
$form.Controls.Add($pnlStatus)

$lblStatusTitle = New-Object Windows.Forms.Label
$lblStatusTitle.Text = "Current DNS Status"
$lblStatusTitle.Font = New-Object Drawing.Font("Segoe UI",10,[Drawing.FontStyle]::Bold)
$lblStatusTitle.ForeColor = $script:Dark.Text
$lblStatusTitle.Location = New-Object Drawing.Point(10,6)
$lblStatusTitle.AutoSize = $true
$pnlStatus.Controls.Add($lblStatusTitle)

$lblStatus = New-Object Windows.Forms.Label
$lblStatus.Location = New-Object Drawing.Point(10,28)
$lblStatus.Size = New-Object Drawing.Size(605,52)
$lblStatus.ForeColor = $script:Dark.Status
$lblStatus.Font = New-Object Drawing.Font("Consolas",9)
$lblStatus.Anchor = "Top,Left,Right"
$pnlStatus.Controls.Add($lblStatus)
#endregion

#region Adapter Selection
$lblAdapter = New-Object Windows.Forms.Label
$lblAdapter.Text = "Network Adapter:"
$lblAdapter.ForeColor = $script:Dark.Text
$lblAdapter.Location = New-Object Drawing.Point(20,140)
$lblAdapter.AutoSize = $true
$form.Controls.Add($lblAdapter)

$cmbAdapter = New-Object Windows.Forms.ComboBox
$cmbAdapter.Location = New-Object Drawing.Point(140,137)
$cmbAdapter.Size = New-Object Drawing.Size(420,25)
$cmbAdapter.DropDownStyle = "DropDownList"
$cmbAdapter.BackColor = $script:Dark.Btn
$cmbAdapter.ForeColor = $script:Dark.Text
$cmbAdapter.FlatStyle = "Flat"
$cmbAdapter.Anchor = "Top,Left,Right"
$form.Controls.Add($cmbAdapter)

$btnRefresh = New-Object Windows.Forms.Button
$btnRefresh.Text = "Refresh"
$btnRefresh.Size = New-Object Drawing.Size(80,27)
$btnRefresh.Location = New-Object Drawing.Point(565,135)
$btnRefresh.BackColor = $script:Dark.Btn
$btnRefresh.ForeColor = $script:Dark.Text
$btnRefresh.FlatStyle = "Flat"
$btnRefresh.Anchor = "Top,Right"
$form.Controls.Add($btnRefresh)
#endregion

#region DNS Panel
$pnlDNS = New-Object Windows.Forms.Panel
$pnlDNS.Location = New-Object Drawing.Point(20,170)
$pnlDNS.Size = New-Object Drawing.Size(625,145)
$pnlDNS.BackColor = $script:Dark.Panel
$pnlDNS.Anchor = "Top,Left,Right"
$form.Controls.Add($pnlDNS)

$lblDNSTitle = New-Object Windows.Forms.Label
$lblDNSTitle.Text = "Select DNS Provider"
$lblDNSTitle.Font = New-Object Drawing.Font("Segoe UI",10,[Drawing.FontStyle]::Bold)
$lblDNSTitle.ForeColor = $script:Dark.Text
$lblDNSTitle.Location = New-Object Drawing.Point(10,6)
$lblDNSTitle.AutoSize = $true
$pnlDNS.Controls.Add($lblDNSTitle)

$cmbDNS = New-Object Windows.Forms.ComboBox
$cmbDNS.Location = New-Object Drawing.Point(10,30)
$cmbDNS.Size = New-Object Drawing.Size(180,25)
$cmbDNS.DropDownStyle = "DropDownList"
$cmbDNS.BackColor = $script:Dark.Btn
$cmbDNS.ForeColor = $script:Dark.Text
$cmbDNS.FlatStyle = "Flat"
foreach($d in $script:DNSPresets.Keys){ $cmbDNS.Items.Add($d) | Out-Null }
$cmbDNS.SelectedIndex = 0
$pnlDNS.Controls.Add($cmbDNS)

$chkIPv6 = New-Object Windows.Forms.CheckBox
$chkIPv6.Text = "IPv6"
$chkIPv6.ForeColor = $script:Dark.Text
$chkIPv6.Location = New-Object Drawing.Point(200,32)
$chkIPv6.Size = New-Object Drawing.Size(70,22)
$chkIPv6.Checked = $true
$pnlDNS.Controls.Add($chkIPv6)

$lblIPv4 = New-Object Windows.Forms.Label
$lblIPv4.Text = "IPv4:"
$lblIPv4.ForeColor = [Drawing.Color]::LightGray
$lblIPv4.Font = New-Object Drawing.Font("Consolas",9)
$lblIPv4.Location = New-Object Drawing.Point(10,60)
$lblIPv4.Size = New-Object Drawing.Size(400,16)
$pnlDNS.Controls.Add($lblIPv4)

$lblIPv6 = New-Object Windows.Forms.Label
$lblIPv6.Text = "IPv6:"
$lblIPv6.ForeColor = [Drawing.Color]::LightGray
$lblIPv6.Font = New-Object Drawing.Font("Consolas",9)
$lblIPv6.Location = New-Object Drawing.Point(10,78)
$lblIPv6.Size = New-Object Drawing.Size(600,16)
$pnlDNS.Controls.Add($lblIPv6)

# Action Buttons Row
$btnApply = New-Object Windows.Forms.Button
$btnApply.Text = "Apply DNS"
$btnApply.Size = New-Object Drawing.Size(100,32)
$btnApply.Location = New-Object Drawing.Point(10,100)
$btnApply.BackColor = [Drawing.Color]::FromArgb(0,140,90)
$btnApply.ForeColor = [Drawing.Color]::White
$btnApply.FlatStyle = "Flat"
$btnApply.Font = New-Object Drawing.Font("Segoe UI",9,[Drawing.FontStyle]::Bold)
$pnlDNS.Controls.Add($btnApply)

$btnReset = New-Object Windows.Forms.Button
$btnReset.Text = "Reset DHCP"
$btnReset.Size = New-Object Drawing.Size(100,32)
$btnReset.Location = New-Object Drawing.Point(120,100)
$btnReset.BackColor = [Drawing.Color]::FromArgb(180,80,0)
$btnReset.ForeColor = [Drawing.Color]::White
$btnReset.FlatStyle = "Flat"
$pnlDNS.Controls.Add($btnReset)

$btnBenchmark = New-Object Windows.Forms.Button
$btnBenchmark.Text = "Benchmark"
$btnBenchmark.Size = New-Object Drawing.Size(100,32)
$btnBenchmark.Location = New-Object Drawing.Point(230,100)
$btnBenchmark.BackColor = [Drawing.Color]::FromArgb(80,50,120)
$btnBenchmark.ForeColor = [Drawing.Color]::White
$btnBenchmark.FlatStyle = "Flat"
$pnlDNS.Controls.Add($btnBenchmark)

# Benchmark Mode Radio Buttons - vertical
$radICMP = New-Object Windows.Forms.RadioButton
$radICMP.Text = "ICMP Ping"
$radICMP.ForeColor = [Drawing.Color]::FromArgb(180,150,255)
$radICMP.Location = New-Object Drawing.Point(340,100)
$radICMP.Size = New-Object Drawing.Size(90,18)
$radICMP.Checked = $true
$pnlDNS.Controls.Add($radICMP)

$radDNS = New-Object Windows.Forms.RadioButton
$radDNS.Text = "DNS Latency"
$radDNS.ForeColor = [Drawing.Color]::FromArgb(150,200,255)
$radDNS.Location = New-Object Drawing.Point(340,118)
$radDNS.Size = New-Object Drawing.Size(100,18)
$pnlDNS.Controls.Add($radDNS)
#endregion

#region Tools Panel
$pnlTools = New-Object Windows.Forms.Panel
$pnlTools.Location = New-Object Drawing.Point(20,325)
$pnlTools.Size = New-Object Drawing.Size(625,42)
$pnlTools.BackColor = $script:Dark.Panel
$pnlTools.Anchor = "Top,Left,Right"
$form.Controls.Add($pnlTools)

$btnFlush = New-Object Windows.Forms.Button
$btnFlush.Text = "Flush DNS"
$btnFlush.Size = New-Object Drawing.Size(90,30)
$btnFlush.Location = New-Object Drawing.Point(10,6)
$btnFlush.BackColor = $script:Dark.Btn
$btnFlush.ForeColor = $script:Dark.Text
$btnFlush.FlatStyle = "Flat"
$pnlTools.Controls.Add($btnFlush)

$btnNetwork = New-Object Windows.Forms.Button
$btnNetwork.Text = "Network"
$btnNetwork.Size = New-Object Drawing.Size(80,30)
$btnNetwork.Location = New-Object Drawing.Point(110,6)
$btnNetwork.BackColor = $script:Dark.Btn
$btnNetwork.ForeColor = $script:Dark.Text
$btnNetwork.FlatStyle = "Flat"
$pnlTools.Controls.Add($btnNetwork)

$btnCheckPing = New-Object Windows.Forms.Button
$btnCheckPing.Text = "Check Ping"
$btnCheckPing.Size = New-Object Drawing.Size(90,30)
$btnCheckPing.Location = New-Object Drawing.Point(200,6)
$btnCheckPing.BackColor = $script:Dark.Btn
$btnCheckPing.ForeColor = $script:Dark.Text
$btnCheckPing.FlatStyle = "Flat"
$pnlTools.Controls.Add($btnCheckPing)

$btnSpeed = New-Object Windows.Forms.Button
$btnSpeed.Text = "Speed Test"
$btnSpeed.Size = New-Object Drawing.Size(90,30)
$btnSpeed.Location = New-Object Drawing.Point(300,6)
$btnSpeed.BackColor = [Drawing.Color]::FromArgb(200,100,0)
$btnSpeed.ForeColor = [Drawing.Color]::White
$btnSpeed.FlatStyle = "Flat"
$pnlTools.Controls.Add($btnSpeed)
#endregion

#region Log Panel
$pnlLog = New-Object Windows.Forms.Panel
$pnlLog.Location = New-Object Drawing.Point(20,375)
$pnlLog.Size = New-Object Drawing.Size(625,210)
$pnlLog.BackColor = $script:Dark.Panel
$pnlLog.Anchor = "Top,Bottom,Left,Right"
$form.Controls.Add($pnlLog)

$lblLogTitle = New-Object Windows.Forms.Label
$lblLogTitle.Text = "Log"
$lblLogTitle.Font = New-Object Drawing.Font("Segoe UI",10,[Drawing.FontStyle]::Bold)
$lblLogTitle.ForeColor = $script:Dark.Text
$lblLogTitle.Location = New-Object Drawing.Point(10,6)
$lblLogTitle.AutoSize = $true
$pnlLog.Controls.Add($lblLogTitle)

$btnClear = New-Object Windows.Forms.Button
$btnClear.Text = "Clear"
$btnClear.Size = New-Object Drawing.Size(55,22)
$btnClear.Location = New-Object Drawing.Point(560,4)
$btnClear.BackColor = $script:Dark.Btn
$btnClear.ForeColor = $script:Dark.Text
$btnClear.FlatStyle = "Flat"
$btnClear.Font = New-Object Drawing.Font("Segoe UI",8)
$btnClear.Anchor = "Top,Right"
$pnlLog.Controls.Add($btnClear)

$txtLog = New-Object Windows.Forms.TextBox
$txtLog.Location = New-Object Drawing.Point(10,28)
$txtLog.Size = New-Object Drawing.Size(605,165)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Both"
$txtLog.ReadOnly = $true
$txtLog.BackColor = $script:Dark.LogBg
$txtLog.ForeColor = $script:Dark.LogText
$txtLog.Font = New-Object Drawing.Font("Consolas",9)
$txtLog.BorderStyle = "FixedSingle"
$txtLog.Anchor = "Top,Bottom,Left,Right"
$pnlLog.Controls.Add($txtLog)
#endregion

#region Footer
$lblAuthor = New-Object Windows.Forms.Label
$lblAuthor.Text = "Author: @anhhackta"
$lblAuthor.ForeColor = [Drawing.Color]::Gray
$lblAuthor.Location = New-Object Drawing.Point(20,595)
$lblAuthor.AutoSize = $true
$lblAuthor.Anchor = "Bottom,Left"
$form.Controls.Add($lblAuthor)

$lnkGitHub = New-Object Windows.Forms.LinkLabel
$lnkGitHub.Text = "GitHub"
$lnkGitHub.LinkColor = $script:Dark.Accent
$lnkGitHub.Location = New-Object Drawing.Point(155,595)
$lnkGitHub.AutoSize = $true
$lnkGitHub.Anchor = "Bottom,Left"
$form.Controls.Add($lnkGitHub)

$lblNet = New-Object Windows.Forms.Label
$lblNet.Text = "Checking..."
$lblNet.ForeColor = [Drawing.Color]::Orange
$lblNet.Location = New-Object Drawing.Point(420,595)
$lblNet.Size = New-Object Drawing.Size(230,20)
$lblNet.TextAlign = "MiddleRight"
$lblNet.Anchor = "Bottom,Right"
$form.Controls.Add($lblNet)
#endregion

#region Runtime Functions
function Log { 
    param([string]$M)
    $txtLog.AppendText("[$(Get-Date -F 'HH:mm:ss')] $M`r`n")
    $txtLog.ScrollToCaret()
    [Windows.Forms.Application]::DoEvents()
}

function RefreshStatus {
    $adapters = Get-ActiveAdapters
    $cmbAdapter.Items.Clear()
    foreach($a in $adapters){ $cmbAdapter.Items.Add($a.Name) | Out-Null }
    if($cmbAdapter.Items.Count -gt 0){ $cmbAdapter.SelectedIndex = 0 }
    
    $status = Get-CurrentDNSStatus
    $txt = ""
    foreach($s in $status){
        $prov = Get-DNSProviderName -IP ($s.IPv4 -split ",")[0].Trim()
        $txt += "$($s.Name): [$prov]`r`n  IPv4: $(if($s.IPv4){$s.IPv4}else{'DHCP'})`r`n  IPv6: $(if($s.IPv6){$s.IPv6}else{'DHCP'})`r`n"
    }
    $lblStatus.Text = $txt.TrimEnd()
    UpdateNetStatus
}

function UpdateNetStatus {
    $hasNet = Test-InternetConnection
    $adapters = Get-ActiveAdapters
    if($hasNet -and $adapters){
        $name = ($adapters | Select-Object -First 1).Name
        $lblNet.Text = "$(T 'Internet'): $name"
        $lblNet.ForeColor = [Drawing.Color]::LimeGreen
    } elseif($adapters) {
        $lblNet.Text = T 'NoInternet'
        $lblNet.ForeColor = [Drawing.Color]::Orange
    } else {
        $lblNet.Text = T 'NoInternet'
        $lblNet.ForeColor = [Drawing.Color]::Red
    }
}

function UpdateDNSInfo {
    $sel = $cmbDNS.SelectedItem
    if($sel -and $script:DNSPresets[$sel]){
        $d = $script:DNSPresets[$sel]
        $lblIPv4.Text = "IPv4: $($d.IPv4[0]) | $($d.IPv4[1])"
        $lblIPv6.Text = if($d.IPv6[0]){"IPv6: $($d.IPv6[0])"}else{"IPv6: N/A"}
        $chkIPv6.Enabled = [bool]$d.IPv6[0]
    }
}

function GetAdapterIndex {
    $n = $cmbAdapter.SelectedItem
    if($n){ return (Get-NetAdapter|Where-Object{$_.Name -eq $n}).ifIndex }
    return $null
}

function ApplyTheme {
    $t = GetTheme
    $form.BackColor = $t.Form
    $pnlStatus.BackColor = $t.Panel; $pnlDNS.BackColor = $t.Panel
    $pnlTools.BackColor = $t.Panel; $pnlLog.BackColor = $t.Panel
    $lblTitle.ForeColor = $t.Accent; $lblStatusTitle.ForeColor = $t.Text
    $lblDNSTitle.ForeColor = $t.Text; $lblLogTitle.ForeColor = $t.Text
    $lblAdapter.ForeColor = $t.Text; $chkIPv6.ForeColor = $t.Text
    $lblStatus.ForeColor = $t.Status; $txtLog.BackColor = $t.LogBg; $txtLog.ForeColor = $t.LogText
    $cmbAdapter.BackColor = $t.Btn; $cmbAdapter.ForeColor = $t.Text
    $cmbLang.BackColor = $t.Btn; $cmbLang.ForeColor = $t.Text
    $cmbDNS.BackColor = $t.Btn; $cmbDNS.ForeColor = $t.Text
    $btnRefresh.BackColor = $t.Btn; $btnRefresh.ForeColor = $t.Text
    $btnPing.BackColor = $t.Btn; $btnPing.ForeColor = $t.Text
    $btnFlush.BackColor = $t.Btn; $btnFlush.ForeColor = $t.Text
    $btnNetwork.BackColor = $t.Btn; $btnNetwork.ForeColor = $t.Text
    $btnClear.BackColor = $t.Btn; $btnClear.ForeColor = $t.Text
    $btnTheme.BackColor = $t.Btn
    $btnTheme.Text = if($script:IsDarkTheme){[char]0x0052}else{[char]0x0053}  # Sun or Moon in Wingdings
    $btnTheme.ForeColor = if($script:IsDarkTheme){[Drawing.Color]::Gold}else{[Drawing.Color]::MidnightBlue}
    $lblIPv4.ForeColor = if($script:IsDarkTheme){[Drawing.Color]::LightGray}else{[Drawing.Color]::DimGray}
    $lblIPv6.ForeColor = if($script:IsDarkTheme){[Drawing.Color]::LightGray}else{[Drawing.Color]::DimGray}
    $lnkGitHub.LinkColor = $t.Accent
}

function UpdateLang {
    $lblAdmin.Text = T 'Admin'; $lblStatusTitle.Text = T 'CurrentStatus'
    $lblAdapter.Text = T 'NetworkAdapter'; $btnRefresh.Text = T 'Refresh'
    $lblDNSTitle.Text = T 'SelectDNS'; $btnApply.Text = T 'ApplyDNS'
    $btnReset.Text = T 'ResetDHCP'; $btnPing.Text = T 'PingTest'
    $btnBenchmark.Text = T 'BenchmarkAll'; $btnFlush.Text = T 'FlushCache'
    $btnNetwork.Text = T 'NetworkSettings'; $btnSpeed.Text = T 'SpeedTest'
    $lblLogTitle.Text = T 'Log'; $btnClear.Text = T 'Clear'
    $lblAuthor.Text = T 'Author'
}
#endregion

#region Events
$btnTheme.Add_Click({
    $script:IsDarkTheme = -not $script:IsDarkTheme
    ApplyTheme
})

$cmbLang.Add_SelectedIndexChanged({
    $script:CurrentLang = if($cmbLang.SelectedIndex -eq 0){"EN"}else{"VI"}
    UpdateLang
})

$cmbDNS.Add_SelectedIndexChanged({ UpdateDNSInfo })
$btnRefresh.Add_Click({ RefreshStatus; Log "[OK] $(T 'LogRefreshed')" })
$btnClear.Add_Click({ $txtLog.Clear() })
$lnkGitHub.Add_Click({ Start-Process "https://github.com/anhhackta" })
$btnNetwork.Add_Click({ Start-Process "ncpa.cpl" })
$btnFlush.Add_Click({ Clear-DnsClientCache; Log "[OK] $(T 'LogFlushed')" })

$btnApply.Add_Click({
    $idx = GetAdapterIndex
    if(-not $idx){ Log "[$(T 'LogError')] $(T 'NoAdapter')"; return }
    $sel = $cmbDNS.SelectedItem; $d = $script:DNSPresets[$sel]
    Log "$(T 'LogApplying') $sel..."
    Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses $d.IPv4 -EA 0
    Log "[OK] $(T 'LogIPv4Set')"
    if($chkIPv6.Checked -and $d.IPv6[0]){
        Set-DnsClientServerAddress -InterfaceIndex $idx -ServerAddresses $d.IPv6 -EA 0
        Log "[OK] $(T 'LogIPv6Set')"
    }
    Clear-DnsClientCache; RefreshStatus; Log "[OK] $(T 'LogDone')"
})

$btnReset.Add_Click({
    $idx = GetAdapterIndex
    if(-not $idx){ Log "[$(T 'LogError')] $(T 'NoAdapter')"; return }
    Log "$(T 'LogReset')"
    Set-DnsClientServerAddress -InterfaceIndex $idx -ResetServerAddresses
    Clear-DnsClientCache; RefreshStatus; Log "[OK] $(T 'LogResetOK')"
})

$btnCheckPing.Add_Click({
    Log "Checking current machine ping..."
    # Get current DNS from machine
    $currentDNS = (Get-DnsClientServerAddress -AddressFamily IPv4 -EA 0 | Where-Object { $_.ServerAddresses } | Select-Object -First 1).ServerAddresses
    if($currentDNS){
        foreach($dns in $currentDNS){
            $r = Test-DNSPing -DNS $dns
            $provName = Get-DNSProviderName -IP $dns
            if($r.Success){ Log "[OK] $provName ($dns) - $($r.Avg) ms" }
            else { Log "[$(T 'LogFailed')] $provName ($dns)" }
        }
    } else {
        Log "[$(T 'LogError')] No DNS configured"
    }
})

$btnBenchmark.Add_Click({
    $mode = if($radDNS.Checked){"DNS Latency"}else{"ICMP Ping"}
    Log "$(T 'LogBenchmark') [$mode]"
    Log ("-"*50)
    $results = @()
    foreach($p in $script:DNSPresets.GetEnumerator()){
        [Windows.Forms.Application]::DoEvents()
        if($radDNS.Checked){
            $r = Test-DNSLatency -Server $p.Value.IPv4[0]; $lat = $r.Latency
        } else {
            $r = Test-DNSPing -DNS $p.Value.IPv4[0]; $lat = $r.Avg
        }
        if($r.Success -and $lat -lt 9999){
            $results += @{Name=$p.Key;Lat=$lat}
            Log "$($p.Key.PadRight(18)) $lat ms"
        } else { Log "$($p.Key.PadRight(18)) $(T 'LogFailed')" }
    }
    Log ("-"*50)
    if($results){ $best = $results|Sort-Object Lat|Select-Object -First 1; Log "[$(T 'LogBest')] $($best.Name) - $($best.Lat) ms" }
})

$btnSpeed.Add_Click({
    Log "$(T 'LogSpeedTest')"
    try {
        $web = New-Object Net.WebClient
        # Download test
        Log "Testing download speed..."
        $s = Get-Date
        $data = $web.DownloadData("https://speed.cloudflare.com/__down?bytes=10000000")
        $sec = ((Get-Date)-$s).TotalSeconds
        $dlMbps = ($data.Length * 8) / ($sec * 1000000)
        Log "[Download] $([math]::Round($dlMbps,2)) Mbps"
        
        # Upload test
        Log "Testing upload speed..."
        $uploadData = New-Object byte[] 2000000  # 2MB
        $s = Get-Date
        $response = $web.UploadData("https://speed.cloudflare.com/__up", $uploadData)
        $sec = ((Get-Date)-$s).TotalSeconds
        $ulMbps = ($uploadData.Length * 8) / ($sec * 1000000)
        Log "[Upload] $([math]::Round($ulMbps,2)) Mbps"
        
        Log "[$(T 'LogSpeed')] DL: $([math]::Round($dlMbps,2)) / UL: $([math]::Round($ulMbps,2)) Mbps"
    } catch { Log "[$(T 'LogError')] Speed test failed: $_" }
})
#endregion

#region Init
RefreshStatus
UpdateDNSInfo
ApplyTheme
Log "$(T 'LogStarted')"
[Windows.Forms.Application]::Run($form)
#endregion

#>
