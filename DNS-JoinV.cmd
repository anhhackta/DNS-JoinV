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
        AlsoIPv6 = "IPv6"; ApplyDNS = "Apply DNS"; ResetDHCP = "Reset DHCP"
        BenchmarkAll = "Benchmark"; FlushCache = "Flush DNS"; NetworkSettings = "Network"
        CheckPing = "Check Ping"; SpeedTest = "Speed Test"; Log = "Log"; Clear = "Clear"; Author = "@anhhackta"
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
        AlsoIPv6 = "IPv6"; ApplyDNS = "Ap Dung"; ResetDHCP = "DHCP"
        BenchmarkAll = "Danh Gia"; FlushCache = "Xoa Cache"; NetworkSettings = "Mang"
        CheckPing = "Kiem Tra Ping"; SpeedTest = "Toc Do"; Log = "Nhat Ky"; Clear = "Xoa"; Author = "@anhhackta"
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
$form.Text = "DNS JoinV v1.1"
$form.Size = New-Object Drawing.Size(680,640)
$form.MinimumSize = New-Object Drawing.Size(680,600)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"  # Prevent resize issues
$form.MaximizeBox = $false  # Disable maximize to avoid layout bugs
$form.BackColor = $script:Dark.Form
$form.Font = New-Object Drawing.Font("Segoe UI",9)

# Icon - create a simple DNS icon using GDI+ (transparent bg)
try {
    $bmp = New-Object Drawing.Bitmap(32,32)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = "AntiAlias"
    $g.Clear([Drawing.Color]::Transparent)
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
$lblTitle.Location = New-Object Drawing.Point(20,10)
$lblTitle.AutoSize = $true
$form.Controls.Add($lblTitle)

$lblAdmin = New-Object Windows.Forms.Label
$lblAdmin.Text = "[Admin]"
$lblAdmin.ForeColor = [Drawing.Color]::FromArgb(100,180,100)
$lblAdmin.Font = New-Object Drawing.Font("Segoe UI",8)
$lblAdmin.Location = New-Object Drawing.Point(158,18)
$lblAdmin.AutoSize = $true
$form.Controls.Add($lblAdmin)

# Unified Settings Panel (Theme + Language)
$pnlSettings = New-Object Windows.Forms.Panel
$pnlSettings.Location = New-Object Drawing.Point(540,8)
$pnlSettings.Size = New-Object Drawing.Size(110,28)
$pnlSettings.BackColor = $script:Dark.Panel
$form.Controls.Add($pnlSettings)

# Theme Icon (Label-based for cleaner look)
$lblTheme = New-Object Windows.Forms.Label
$lblTheme.Text = [char]0x263C  # Sun symbol
$lblTheme.Font = New-Object Drawing.Font("Segoe UI Symbol",14)
$lblTheme.Size = New-Object Drawing.Size(26,24)
$lblTheme.Location = New-Object Drawing.Point(4,2)
$lblTheme.BackColor = $script:Dark.Panel  # Match panel background
$lblTheme.ForeColor = [Drawing.Color]::Gold
$lblTheme.TextAlign = "MiddleCenter"
$lblTheme.Cursor = "Hand"
$pnlSettings.Controls.Add($lblTheme)

$cmbLang = New-Object Windows.Forms.ComboBox
$cmbLang.Location = New-Object Drawing.Point(34,3)
$cmbLang.Size = New-Object Drawing.Size(70,22)
$cmbLang.DropDownStyle = "DropDownList"
$cmbLang.BackColor = $script:Dark.Btn
$cmbLang.ForeColor = $script:Dark.Text
$cmbLang.FlatStyle = "Flat"
$cmbLang.Items.AddRange(@("English","Vietnamese"))
$cmbLang.SelectedIndex = 0
$pnlSettings.Controls.Add($cmbLang)
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
$lblAdapter.Location = New-Object Drawing.Point(20,138)
$lblAdapter.AutoSize = $true
$form.Controls.Add($lblAdapter)

$cmbAdapter = New-Object Windows.Forms.ComboBox
$cmbAdapter.Location = New-Object Drawing.Point(140,135)
$cmbAdapter.Size = New-Object Drawing.Size(400,24)
$cmbAdapter.DropDownStyle = "DropDownList"
$cmbAdapter.BackColor = $script:Dark.Btn
$cmbAdapter.ForeColor = $script:Dark.Text
$cmbAdapter.FlatStyle = "Standard"
$form.Controls.Add($cmbAdapter)

$btnRefresh = New-Object Windows.Forms.Button
$btnRefresh.Text = "Refresh"
$btnRefresh.Size = New-Object Drawing.Size(70,24)
$btnRefresh.Location = New-Object Drawing.Point(560,135)
$btnRefresh.BackColor = $script:Dark.Btn
$btnRefresh.ForeColor = $script:Dark.Text
$btnRefresh.FlatStyle = "Flat"
$btnRefresh.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
$form.Controls.Add($btnRefresh)
#endregion

#region DNS Panel
$pnlDNS = New-Object Windows.Forms.Panel
$pnlDNS.Location = New-Object Drawing.Point(20,170)
$pnlDNS.Size = New-Object Drawing.Size(625,145)
$pnlDNS.BackColor = $script:Dark.Panel
$form.Controls.Add($pnlDNS)

$lblDNSTitle = New-Object Windows.Forms.Label
$lblDNSTitle.Text = "Select DNS Provider"
$lblDNSTitle.Font = New-Object Drawing.Font("Segoe UI",10,[Drawing.FontStyle]::Bold)
$lblDNSTitle.ForeColor = $script:Dark.Text
$lblDNSTitle.Location = New-Object Drawing.Point(10,6)
$lblDNSTitle.AutoSize = $true
$pnlDNS.Controls.Add($lblDNSTitle)

# PC Info - stacked vertically (name on top, IP below, click-to-copy IP)
$lblPCName = New-Object Windows.Forms.Label
$lblPCName.Text = ""
$lblPCName.Font = New-Object Drawing.Font("Segoe UI",9,[Drawing.FontStyle]::Bold)
$lblPCName.ForeColor = [Drawing.Color]::FromArgb(150,150,150)
$lblPCName.Location = New-Object Drawing.Point(480,4)
$lblPCName.Size = New-Object Drawing.Size(140,16)
$lblPCName.TextAlign = "MiddleRight"
$pnlDNS.Controls.Add($lblPCName)

$lblPCIP = New-Object Windows.Forms.Label
$lblPCIP.Text = ""
$lblPCIP.Font = New-Object Drawing.Font("Consolas",9,[Drawing.FontStyle]::Bold)
$lblPCIP.ForeColor = [Drawing.Color]::FromArgb(0,180,130)
$lblPCIP.Location = New-Object Drawing.Point(480,20)
$lblPCIP.Size = New-Object Drawing.Size(140,16)
$lblPCIP.TextAlign = "MiddleRight"
$lblPCIP.Cursor = "Hand"
$pnlDNS.Controls.Add($lblPCIP)

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
$btnApply.Size = New-Object Drawing.Size(100,30)
$btnApply.Location = New-Object Drawing.Point(10,108)
$btnApply.BackColor = [Drawing.Color]::FromArgb(0,130,100)
$btnApply.ForeColor = [Drawing.Color]::White
$btnApply.FlatStyle = "Flat"
$btnApply.FlatAppearance.BorderSize = 0
$btnApply.Font = New-Object Drawing.Font("Segoe UI",9,[Drawing.FontStyle]::Bold)
$pnlDNS.Controls.Add($btnApply)

$btnReset = New-Object Windows.Forms.Button
$btnReset.Text = "Reset DHCP"
$btnReset.Size = New-Object Drawing.Size(100,30)
$btnReset.Location = New-Object Drawing.Point(115,108)
$btnReset.BackColor = [Drawing.Color]::FromArgb(80,80,80)
$btnReset.ForeColor = [Drawing.Color]::White
$btnReset.FlatStyle = "Flat"
$btnReset.FlatAppearance.BorderSize = 0
$pnlDNS.Controls.Add($btnReset)

$btnBenchmark = New-Object Windows.Forms.Button
$btnBenchmark.Text = "Benchmark"
$btnBenchmark.Size = New-Object Drawing.Size(100,30)
$btnBenchmark.Location = New-Object Drawing.Point(220,108)
$btnBenchmark.BackColor = [Drawing.Color]::FromArgb(0,130,100)
$btnBenchmark.ForeColor = [Drawing.Color]::White
$btnBenchmark.FlatStyle = "Flat"
$btnBenchmark.FlatAppearance.BorderSize = 0
$pnlDNS.Controls.Add($btnBenchmark)

# Domain Check - multiline TextBox on right side (same style as Log)
$script:DefaultDomains = "google.com`r`ncloudflare.com`r`nyoutube.com`r`nfacebook.com`r`nmicrosoft.com"
$txtDomains = New-Object Windows.Forms.TextBox
$txtDomains.Text = $script:DefaultDomains
$txtDomains.Location = New-Object Drawing.Point(330,30)
$txtDomains.Size = New-Object Drawing.Size(180,75)
$txtDomains.Multiline = $true
$txtDomains.ScrollBars = "Vertical"
$txtDomains.BackColor = $script:Dark.LogBg
$txtDomains.ForeColor = $script:Dark.LogText
$txtDomains.Font = New-Object Drawing.Font("Consolas",8.5)
$txtDomains.BorderStyle = "FixedSingle"
$pnlDNS.Controls.Add($txtDomains)

$lblDomains = New-Object Windows.Forms.Label
$lblDomains.Text = "Test Domains"
$lblDomains.Font = New-Object Drawing.Font("Segoe UI",8)
$lblDomains.ForeColor = [Drawing.Color]::FromArgb(120,120,120)
$lblDomains.Location = New-Object Drawing.Point(330,108)
$lblDomains.AutoSize = $true
$pnlDNS.Controls.Add($lblDomains)

$btnResetDomains = New-Object Windows.Forms.Button
$btnResetDomains.Text = "Reset"
$btnResetDomains.Size = New-Object Drawing.Size(50,22)
$btnResetDomains.Location = New-Object Drawing.Point(460,106)
$btnResetDomains.BackColor = $script:Dark.Btn
$btnResetDomains.ForeColor = $script:Dark.Text
$btnResetDomains.FlatStyle = "Flat"
$btnResetDomains.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
$btnResetDomains.Font = New-Object Drawing.Font("Segoe UI",7)
$pnlDNS.Controls.Add($btnResetDomains)
#endregion

#region Tools Panel
$pnlTools = New-Object Windows.Forms.Panel
$pnlTools.Location = New-Object Drawing.Point(20,325)
$pnlTools.Size = New-Object Drawing.Size(625,40)
$pnlTools.BackColor = $script:Dark.Panel
$form.Controls.Add($pnlTools)

$btnFlush = New-Object Windows.Forms.Button
$btnFlush.Text = "Flush DNS"
$btnFlush.Size = New-Object Drawing.Size(85,28)
$btnFlush.Location = New-Object Drawing.Point(8,6)
$btnFlush.BackColor = $script:Dark.Btn
$btnFlush.ForeColor = $script:Dark.Text
$btnFlush.FlatStyle = "Flat"
$btnFlush.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
$pnlTools.Controls.Add($btnFlush)

$btnNetwork = New-Object Windows.Forms.Button
$btnNetwork.Text = "Network"
$btnNetwork.Size = New-Object Drawing.Size(75,28)
$btnNetwork.Location = New-Object Drawing.Point(98,6)
$btnNetwork.BackColor = $script:Dark.Btn
$btnNetwork.ForeColor = $script:Dark.Text
$btnNetwork.FlatStyle = "Flat"
$btnNetwork.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
$pnlTools.Controls.Add($btnNetwork)

$btnCheckPing = New-Object Windows.Forms.Button
$btnCheckPing.Text = "Check Ping"
$btnCheckPing.Size = New-Object Drawing.Size(85,28)
$btnCheckPing.Location = New-Object Drawing.Point(178,6)
$btnCheckPing.BackColor = $script:Dark.Btn
$btnCheckPing.ForeColor = $script:Dark.Text
$btnCheckPing.FlatStyle = "Flat"
$btnCheckPing.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(70,70,70)
$pnlTools.Controls.Add($btnCheckPing)

$btnSpeed = New-Object Windows.Forms.Button
$btnSpeed.Text = "Speed Test"
$btnSpeed.Size = New-Object Drawing.Size(85,28)
$btnSpeed.Location = New-Object Drawing.Point(268,6)
$btnSpeed.BackColor = [Drawing.Color]::FromArgb(0,130,100)  # Teal - Primary
$btnSpeed.ForeColor = [Drawing.Color]::White
$btnSpeed.FlatStyle = "Flat"
$btnSpeed.FlatAppearance.BorderSize = 0
$pnlTools.Controls.Add($btnSpeed)
#endregion

#region Log Panel
$pnlLog = New-Object Windows.Forms.Panel
$pnlLog.Location = New-Object Drawing.Point(20,370)
$pnlLog.Size = New-Object Drawing.Size(625,185)
$pnlLog.BackColor = $script:Dark.Panel
$form.Controls.Add($pnlLog)

$lblLogTitle = New-Object Windows.Forms.Label
$lblLogTitle.Text = "Log"
$lblLogTitle.Font = New-Object Drawing.Font("Segoe UI",9,[Drawing.FontStyle]::Bold)
$lblLogTitle.ForeColor = $script:Dark.Text
$lblLogTitle.Location = New-Object Drawing.Point(8,5)
$lblLogTitle.AutoSize = $true
$pnlLog.Controls.Add($lblLogTitle)

$btnClear = New-Object Windows.Forms.Button
$btnClear.Text = "Clear"
$btnClear.Size = New-Object Drawing.Size(55,22)
$btnClear.Location = New-Object Drawing.Point(560,3)
$btnClear.BackColor = [Drawing.Color]::FromArgb(90,50,50)
$btnClear.ForeColor = [Drawing.Color]::White
$btnClear.FlatStyle = "Flat"
$btnClear.FlatAppearance.BorderSize = 0
$btnClear.Font = New-Object Drawing.Font("Segoe UI",8)
$pnlLog.Controls.Add($btnClear)

$txtLog = New-Object Windows.Forms.TextBox
$txtLog.Location = New-Object Drawing.Point(8,26)
$txtLog.Size = New-Object Drawing.Size(608,150)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.BackColor = $script:Dark.LogBg
$txtLog.ForeColor = $script:Dark.LogText
$txtLog.Font = New-Object Drawing.Font("Consolas",8.5)
$txtLog.BorderStyle = "FixedSingle"
$pnlLog.Controls.Add($txtLog)
#endregion

#region Footer
$lblAuthor = New-Object Windows.Forms.Label
$lblAuthor.Text = "@anhhackta"
$lblAuthor.ForeColor = [Drawing.Color]::FromArgb(120,120,120)
$lblAuthor.Font = New-Object Drawing.Font("Segoe UI",8)
$lblAuthor.Location = New-Object Drawing.Point(20,560)
$lblAuthor.AutoSize = $true
$form.Controls.Add($lblAuthor)

$lnkGitHub = New-Object Windows.Forms.LinkLabel
$lnkGitHub.Text = "GitHub"
$lnkGitHub.LinkColor = [Drawing.Color]::FromArgb(0,130,100)
$lnkGitHub.Font = New-Object Drawing.Font("Segoe UI",8)
$lnkGitHub.Location = New-Object Drawing.Point(95,560)
$lnkGitHub.AutoSize = $true
$form.Controls.Add($lnkGitHub)

$lblNet = New-Object Windows.Forms.Label
$lblNet.Text = ""
$lblNet.ForeColor = [Drawing.Color]::Gray
$lblNet.Font = New-Object Drawing.Font("Segoe UI",8)
$lblNet.Location = New-Object Drawing.Point(360,560)
$lblNet.Size = New-Object Drawing.Size(290,18)
$lblNet.TextAlign = "MiddleRight"
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
    
    # Update PC Info - split into name and IP
    $lblPCName.Text = $env:COMPUTERNAME
    $script:LocalIP = (Get-NetIPAddress -AddressFamily IPv4 -EA 0 | Where-Object { $_.IPAddress -notmatch '^127|^169' } | Select-Object -First 1).IPAddress
    if($script:LocalIP){ $lblPCIP.Text = $script:LocalIP }
    else { $lblPCIP.Text = "N/A" }
    
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
    $pnlSettings.BackColor = $t.Panel
    $lblTitle.ForeColor = $t.Accent; $lblStatusTitle.ForeColor = $t.Text
    $lblDNSTitle.ForeColor = $t.Text; $lblLogTitle.ForeColor = $t.Text
    $lblAdapter.ForeColor = $t.Text; $chkIPv6.ForeColor = $t.Text
    $lblStatus.ForeColor = $t.Status; $txtLog.BackColor = $t.LogBg; $txtLog.ForeColor = $t.LogText
    $txtDomains.BackColor = $t.LogBg; $txtDomains.ForeColor = $t.LogText
    $cmbAdapter.BackColor = $t.Btn; $cmbAdapter.ForeColor = $t.Text
    $cmbLang.BackColor = $t.Btn; $cmbLang.ForeColor = $t.Text
    $cmbDNS.BackColor = $t.Btn; $cmbDNS.ForeColor = $t.Text
    $btnRefresh.BackColor = $t.Btn; $btnRefresh.ForeColor = $t.Text
    $btnFlush.BackColor = $t.Btn; $btnFlush.ForeColor = $t.Text
    $btnNetwork.BackColor = $t.Btn; $btnNetwork.ForeColor = $t.Text
    $btnCheckPing.BackColor = $t.Btn; $btnCheckPing.ForeColor = $t.Text
    $btnResetDomains.BackColor = $t.Btn; $btnResetDomains.ForeColor = $t.Text
    # Theme icon
    $lblTheme.BackColor = $t.Panel  # Match panel bg
    $lblTheme.Text = if($script:IsDarkTheme){[char]0x263C}else{[char]0x263E}  # Sun or Moon
    $lblTheme.ForeColor = if($script:IsDarkTheme){[Drawing.Color]::Gold}else{[Drawing.Color]::LightSlateGray}
    $lblIPv4.ForeColor = if($script:IsDarkTheme){[Drawing.Color]::LightGray}else{[Drawing.Color]::DimGray}
    $lblIPv6.ForeColor = if($script:IsDarkTheme){[Drawing.Color]::LightGray}else{[Drawing.Color]::DimGray}
    $lnkGitHub.LinkColor = $t.Accent
}

function UpdateLang {
    $lblAdmin.Text = T 'Admin'; $lblStatusTitle.Text = T 'CurrentStatus'
    $lblAdapter.Text = T 'NetworkAdapter'; $btnRefresh.Text = T 'Refresh'
    $lblDNSTitle.Text = T 'SelectDNS'; $btnApply.Text = T 'ApplyDNS'
    $btnReset.Text = T 'ResetDHCP'; $btnBenchmark.Text = T 'BenchmarkAll'
    $btnFlush.Text = T 'FlushCache'; $btnNetwork.Text = T 'NetworkSettings'
    $btnCheckPing.Text = T 'CheckPing'; $btnSpeed.Text = T 'SpeedTest'
    $lblLogTitle.Text = T 'Log'; $btnClear.Text = T 'Clear'
    $lblAuthor.Text = T 'Author'; $chkIPv6.Text = T 'AlsoIPv6'
    UpdateNetStatus  # Update Internet/NoInternet text
}
#endregion

#region Events
# Theme toggle with hover effect (alpha overlay via color brightness)
$lblTheme.Add_Click({
    $script:IsDarkTheme = -not $script:IsDarkTheme
    ApplyTheme
})
$lblTheme.Add_MouseEnter({
    $lblTheme.ForeColor = if($script:IsDarkTheme){[Drawing.Color]::FromArgb(255,255,200)}else{[Drawing.Color]::FromArgb(80,80,120)}
})
$lblTheme.Add_MouseLeave({
    $lblTheme.ForeColor = if($script:IsDarkTheme){[Drawing.Color]::Gold}else{[Drawing.Color]::LightSlateGray}
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
$btnResetDomains.Add_Click({ $txtDomains.Text = $script:DefaultDomains })

# Copy only IP to clipboard when clicked
$lblPCIP.Add_Click({
    if($script:LocalIP){
        [Windows.Forms.Clipboard]::SetText($script:LocalIP)
        Log "[OK] Copied IP: $script:LocalIP"
    }
})

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
    # Use domains from multiline TextBox (split by newlines)
    $domains = $txtDomains.Text -split "`r`n|`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if(-not $domains){ Log "[$(T 'LogError')] No domains configured"; return }
    
    Log "Checking DNS resolve for $($domains.Count) domains..."
    $totalMs = 0; $successCount = 0; $failCount = 0
    
    foreach($domain in $domains){
        [Windows.Forms.Application]::DoEvents()
        try {
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $result = [Net.Dns]::GetHostAddresses($domain)
            $sw.Stop()
            $ms = $sw.ElapsedMilliseconds
            $totalMs += $ms
            $successCount++
            Log "  [OK] $domain - $ms ms"
        } catch {
            $failCount++
            $errMsg = if($_.Exception.InnerException){ $_.Exception.InnerException.Message }else{ "DNS Fail" }
            Log "  [FAIL] $domain - $errMsg"
        }
    }
    
    Log ("-"*40)
    if($successCount -gt 0){
        $avg = [math]::Round($totalMs / $successCount, 1)
        Log "[RESULT] Avg: $avg ms | OK: $successCount | Fail: $failCount"
    } else {
        Log "[$(T 'LogFailed')] All domains failed"
    }
})

$btnBenchmark.Add_Click({
    Log "$(T 'LogBenchmark') [DNS Query - Multi-Domain]"
    Log ("-"*60)
    
    # Test domains - popular sites
    $testDomains = @("google.com", "youtube.com", "facebook.com", "tiktok.com", "x.com", "cloudflare.com", "steampowered.com")
    $timeout = 3000  # 3 seconds timeout per DNS
    
    Log "Testing $($script:DNSPresets.Count) DNS servers with $($testDomains.Count) domains each..."
    Log ""
    
    # Create jobs for parallel execution - one job per DNS
    $jobs = @()
    foreach($p in $script:DNSPresets.GetEnumerator()){
        $dnsName = $p.Key
        $dnsIP = $p.Value.IPv4[0]
        
        $job = Start-Job -ScriptBlock {
            param($Name, $IP, $Domains, $Timeout)
            
            $domainResults = @()
            $successCount = 0
            $totalLatency = 0
            
            foreach($domain in $Domains){
                try {
                    $sw = [Diagnostics.Stopwatch]::StartNew()
                    $result = Resolve-DnsName -Name $domain -Server $IP -Type A -DnsOnly -EA Stop
                    $sw.Stop()
                    $latency = $sw.ElapsedMilliseconds
                    
                    $domainResults += [PSCustomObject]@{
                        Domain = $domain
                        Latency = $latency
                        Success = $true
                    }
                    $successCount++
                    $totalLatency += $latency
                } catch {
                    $domainResults += [PSCustomObject]@{
                        Domain = $domain
                        Latency = 9999
                        Success = $false
                    }
                }
            }
            
            $avgLatency = if($successCount -gt 0){ [math]::Round($totalLatency / $successCount, 1) } else { 9999 }
            
            return [PSCustomObject]@{
                Name = $Name
                IP = $IP
                AvgLatency = $avgLatency
                SuccessRate = "$successCount/$($Domains.Count)"
                DomainResults = $domainResults
            }
        } -ArgumentList $dnsName, $dnsIP, $testDomains, $timeout
        
        $jobs += @{Name=$dnsName; Job=$job}
    }
    
    # Wait for all jobs with timeout
    $allResults = @()
    foreach($j in $jobs){
        [Windows.Forms.Application]::DoEvents()
        $result = $j.Job | Wait-Job -Timeout 10 | Receive-Job
        Remove-Job -Job $j.Job -Force -EA 0
        
        if($result){
            $allResults += $result
        } else {
            $allResults += [PSCustomObject]@{
                Name = $j.Name
                IP = ""
                AvgLatency = 9999
                SuccessRate = "0/$($testDomains.Count)"
                DomainResults = @()
            }
        }
    }
    
    # Sort by average latency ascending
    $sortedResults = $allResults | Sort-Object AvgLatency
    
    # Display results
    foreach($r in $sortedResults){
        if($r.AvgLatency -lt 9999){
            Log "$($r.Name.PadRight(16)) $($r.AvgLatency.ToString().PadLeft(6)) ms  [$($r.SuccessRate)]"
        } else {
            Log "$($r.Name.PadRight(16)) $(T 'LogFailed')  [$($r.SuccessRate)]"
        }
    }
    
    Log ("-"*60)
    
    # Show best result
    $best = $sortedResults | Where-Object { $_.AvgLatency -lt 9999 } | Select-Object -First 1
    if($best){
        Log "[$(T 'LogBest')] $($best.Name) - $($best.AvgLatency) ms (Avg across $($testDomains.Count) domains)"
    } else {
        Log "[$(T 'LogError')] No DNS servers responded"
    }
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
UpdateLang  # Apply language strings at startup
Log "$(T 'LogStarted')"
[Windows.Forms.Application]::Run($form)
#endregion

#>
