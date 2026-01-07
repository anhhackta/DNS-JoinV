# ============================================
# DNS MANAGER - Simple DNS Management Tool
# Run: irm https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/DNS-Manager.ps1 | iex
# Or: powershell -ExecutionPolicy Bypass -File DNS-Manager.ps1
# ============================================

# Check & Request Admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    $scriptContent = $MyInvocation.MyCommand.ScriptBlock
    if ($scriptContent) {
        Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command & { $scriptContent }" -Verb RunAs
    }
    else {
        # For irm | iex scenario - re-download and run as admin
        $scriptUrl = "https://raw.githubusercontent.com/user/repo/main/DNS-Manager.ps1"
        Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm '$scriptUrl' | iex`"" -Verb RunAs
    }
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Preset DNS Servers
$script:DNSPresets = [ordered]@{
    "Google DNS"    = @("8.8.8.8", "8.8.4.4")
    "Cloudflare"    = @("1.1.1.1", "1.0.0.1")
    "OpenDNS"       = @("208.67.222.222", "208.67.220.220")
    "Quad9"         = @("9.9.9.9", "149.112.112.112")
    "AdGuard DNS"   = @("94.140.14.14", "94.140.15.15")
    "CleanBrowsing" = @("185.228.168.9", "185.228.169.9")
    "Comodo Secure" = @("8.26.56.26", "8.20.247.20")
    "Level3"        = @("209.244.0.3", "209.244.0.4")
    "Verisign"      = @("64.6.64.6", "64.6.65.6")
    "DNS.Watch"     = @("84.200.69.80", "84.200.70.40")
}

# Get active network adapter
function Get-ActiveAdapter {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.PhysicalMediaType -ne "Unspecified" }
    return $adapters | Select-Object -First 1
}

# Get current DNS
function Get-CurrentDNS {
    $adapter = Get-ActiveAdapter
    if ($adapter) {
        $dns = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4
        return @{
            AdapterName    = $adapter.Name
            DNS            = $dns.ServerAddresses -join ", "
            InterfaceIndex = $adapter.ifIndex
        }
    }
    return $null
}

# Set DNS
function Set-DNSServers {
    param([string]$Primary, [string]$Secondary)
    
    $adapter = Get-ActiveAdapter
    if ($adapter) {
        try {
            if ($Secondary) {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses @($Primary, $Secondary)
            }
            else {
                Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses @($Primary)
            }
            Clear-DnsClientCache
            return $true
        }
        catch {
            return $false
        }
    }
    return $false
}

# Reset to DHCP
function Reset-DNSToAuto {
    $adapter = Get-ActiveAdapter
    if ($adapter) {
        try {
            Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses
            Clear-DnsClientCache
            return $true
        }
        catch {
            return $false
        }
    }
    return $false
}

# Ping DNS
function Test-DNSPing {
    param([string]$DNS)
    try {
        $ping = Test-Connection -ComputerName $DNS -Count 4 -ErrorAction Stop
        $avg = ($ping | Measure-Object -Property ResponseTime -Average).Average
        $min = ($ping | Measure-Object -Property ResponseTime -Minimum).Minimum
        $max = ($ping | Measure-Object -Property ResponseTime -Maximum).Maximum
        return @{
            Success = $true
            Average = [math]::Round($avg, 2)
            Min     = $min
            Max     = $max
        }
    }
    catch {
        return @{ Success = $false }
    }
}

# Speed Test (Download test)
function Start-SpeedTest {
    param([System.Windows.Forms.TextBox]$OutputBox)
    
    $testUrls = @(
        @{ Name = "Cloudflare 10MB"; Url = "https://speed.cloudflare.com/__down?bytes=10000000" },
        @{ Name = "Google"; Url = "https://www.google.com/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png" }
    )
    
    $OutputBox.AppendText("`r`n[SPEEDTEST] Starting speed test...`r`n")
    [System.Windows.Forms.Application]::DoEvents()
    
    foreach ($test in $testUrls) {
        try {
            $OutputBox.AppendText("[SPEEDTEST] Testing with $($test.Name)...`r`n")
            [System.Windows.Forms.Application]::DoEvents()
            
            $webClient = New-Object System.Net.WebClient
            $startTime = Get-Date
            $data = $webClient.DownloadData($test.Url)
            $endTime = Get-Date
            
            $duration = ($endTime - $startTime).TotalSeconds
            $sizeBytes = $data.Length
            $sizeMB = $sizeBytes / 1MB
            $speedMbps = ($sizeBytes * 8) / ($duration * 1000000)
            
            $OutputBox.AppendText("[SPEEDTEST] $($test.Name): Downloaded $([math]::Round($sizeMB, 2)) MB in $([math]::Round($duration, 2))s`r`n")
            $OutputBox.AppendText("[SPEEDTEST] Speed: $([math]::Round($speedMbps, 2)) Mbps`r`n")
            $OutputBox.AppendText("-" * 50 + "`r`n")
            [System.Windows.Forms.Application]::DoEvents()
            
        }
        catch {
            $OutputBox.AppendText("[SPEEDTEST] $($test.Name): Failed - $($_.Exception.Message)`r`n")
        }
    }
    
    $OutputBox.AppendText("[SPEEDTEST] Speed test completed!`r`n")
}

# ============================================
# GUI CREATION
# ============================================

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "DNS Manager - Simple DNS Tool"
$form.Size = New-Object System.Drawing.Size(700, 680)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

# Colors
$accentColor = [System.Drawing.Color]::FromArgb(0, 150, 255)
$textColor = [System.Drawing.Color]::White
$panelColor = [System.Drawing.Color]::FromArgb(45, 45, 50)
$buttonColor = [System.Drawing.Color]::FromArgb(60, 60, 70)

# Title Label
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "DNS MANAGER"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = $accentColor
$titleLabel.Location = New-Object System.Drawing.Point(20, 15)
$titleLabel.AutoSize = $true
$form.Controls.Add($titleLabel)

$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "Simple DNS Management Tool - Running as Administrator"
$subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$subtitleLabel.ForeColor = [System.Drawing.Color]::LightGreen
$subtitleLabel.Location = New-Object System.Drawing.Point(22, 48)
$subtitleLabel.AutoSize = $true
$form.Controls.Add($subtitleLabel)

# Current DNS Panel
$currentPanel = New-Object System.Windows.Forms.Panel
$currentPanel.Location = New-Object System.Drawing.Point(20, 75)
$currentPanel.Size = New-Object System.Drawing.Size(645, 80)
$currentPanel.BackColor = $panelColor
$form.Controls.Add($currentPanel)

$lblCurrentTitle = New-Object System.Windows.Forms.Label
$lblCurrentTitle.Text = "Current DNS Status"
$lblCurrentTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblCurrentTitle.ForeColor = $textColor
$lblCurrentTitle.Location = New-Object System.Drawing.Point(10, 8)
$lblCurrentTitle.AutoSize = $true
$currentPanel.Controls.Add($lblCurrentTitle)

$lblAdapter = New-Object System.Windows.Forms.Label
$lblAdapter.Text = "Adapter: Loading..."
$lblAdapter.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 180)
$lblAdapter.Location = New-Object System.Drawing.Point(10, 32)
$lblAdapter.Size = New-Object System.Drawing.Size(620, 20)
$currentPanel.Controls.Add($lblAdapter)

$lblCurrentDNS = New-Object System.Windows.Forms.Label
$lblCurrentDNS.Text = "DNS: Loading..."
$lblCurrentDNS.ForeColor = [System.Drawing.Color]::LightGreen
$lblCurrentDNS.Font = New-Object System.Drawing.Font("Consolas", 10)
$lblCurrentDNS.Location = New-Object System.Drawing.Point(10, 52)
$lblCurrentDNS.Size = New-Object System.Drawing.Size(620, 20)
$currentPanel.Controls.Add($lblCurrentDNS)

# DNS Presets Panel
$presetPanel = New-Object System.Windows.Forms.Panel
$presetPanel.Location = New-Object System.Drawing.Point(20, 165)
$presetPanel.Size = New-Object System.Drawing.Size(320, 200)
$presetPanel.BackColor = $panelColor
$form.Controls.Add($presetPanel)

$lblPresetTitle = New-Object System.Windows.Forms.Label
$lblPresetTitle.Text = "Quick DNS Presets"
$lblPresetTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblPresetTitle.ForeColor = $textColor
$lblPresetTitle.Location = New-Object System.Drawing.Point(10, 8)
$lblPresetTitle.AutoSize = $true
$presetPanel.Controls.Add($lblPresetTitle)

$cmbPresets = New-Object System.Windows.Forms.ComboBox
$cmbPresets.Location = New-Object System.Drawing.Point(10, 35)
$cmbPresets.Size = New-Object System.Drawing.Size(200, 25)
$cmbPresets.DropDownStyle = "DropDownList"
$cmbPresets.BackColor = $buttonColor
$cmbPresets.ForeColor = $textColor
$cmbPresets.FlatStyle = "Flat"
foreach ($preset in $script:DNSPresets.Keys) {
    $cmbPresets.Items.Add($preset) | Out-Null
}
$cmbPresets.SelectedIndex = 0
$presetPanel.Controls.Add($cmbPresets)

$lblPresetDNS = New-Object System.Windows.Forms.Label
$lblPresetDNS.Text = ""
$lblPresetDNS.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 150)
$lblPresetDNS.Font = New-Object System.Drawing.Font("Consolas", 9)
$lblPresetDNS.Location = New-Object System.Drawing.Point(10, 65)
$lblPresetDNS.Size = New-Object System.Drawing.Size(300, 20)
$presetPanel.Controls.Add($lblPresetDNS)

$btnApplyPreset = New-Object System.Windows.Forms.Button
$btnApplyPreset.Text = "Apply Preset"
$btnApplyPreset.Location = New-Object System.Drawing.Point(10, 95)
$btnApplyPreset.Size = New-Object System.Drawing.Size(140, 35)
$btnApplyPreset.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 80)
$btnApplyPreset.ForeColor = $textColor
$btnApplyPreset.FlatStyle = "Flat"
$btnApplyPreset.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnApplyPreset.Cursor = "Hand"
$presetPanel.Controls.Add($btnApplyPreset)

$btnPingPreset = New-Object System.Windows.Forms.Button
$btnPingPreset.Text = "Ping Test"
$btnPingPreset.Location = New-Object System.Drawing.Point(160, 95)
$btnPingPreset.Size = New-Object System.Drawing.Size(140, 35)
$btnPingPreset.BackColor = $buttonColor
$btnPingPreset.ForeColor = $textColor
$btnPingPreset.FlatStyle = "Flat"
$btnPingPreset.Cursor = "Hand"
$presetPanel.Controls.Add($btnPingPreset)

$btnResetDNS = New-Object System.Windows.Forms.Button
$btnResetDNS.Text = "Reset to Auto (DHCP)"
$btnResetDNS.Location = New-Object System.Drawing.Point(10, 145)
$btnResetDNS.Size = New-Object System.Drawing.Size(290, 35)
$btnResetDNS.BackColor = [System.Drawing.Color]::FromArgb(180, 80, 0)
$btnResetDNS.ForeColor = $textColor
$btnResetDNS.FlatStyle = "Flat"
$btnResetDNS.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnResetDNS.Cursor = "Hand"
$presetPanel.Controls.Add($btnResetDNS)

# Custom DNS Panel
$customPanel = New-Object System.Windows.Forms.Panel
$customPanel.Location = New-Object System.Drawing.Point(345, 165)
$customPanel.Size = New-Object System.Drawing.Size(320, 200)
$customPanel.BackColor = $panelColor
$form.Controls.Add($customPanel)

$lblCustomTitle = New-Object System.Windows.Forms.Label
$lblCustomTitle.Text = "Custom DNS"
$lblCustomTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblCustomTitle.ForeColor = $textColor
$lblCustomTitle.Location = New-Object System.Drawing.Point(10, 8)
$lblCustomTitle.AutoSize = $true
$customPanel.Controls.Add($lblCustomTitle)

$lblPrimary = New-Object System.Windows.Forms.Label
$lblPrimary.Text = "Primary DNS:"
$lblPrimary.ForeColor = $textColor
$lblPrimary.Location = New-Object System.Drawing.Point(10, 38)
$lblPrimary.AutoSize = $true
$customPanel.Controls.Add($lblPrimary)

$txtPrimary = New-Object System.Windows.Forms.TextBox
$txtPrimary.Location = New-Object System.Drawing.Point(100, 35)
$txtPrimary.Size = New-Object System.Drawing.Size(200, 25)
$txtPrimary.BackColor = $buttonColor
$txtPrimary.ForeColor = $textColor
$txtPrimary.BorderStyle = "FixedSingle"
$txtPrimary.Font = New-Object System.Drawing.Font("Consolas", 10)
$customPanel.Controls.Add($txtPrimary)

$lblSecondary = New-Object System.Windows.Forms.Label
$lblSecondary.Text = "Secondary DNS:"
$lblSecondary.ForeColor = $textColor
$lblSecondary.Location = New-Object System.Drawing.Point(10, 68)
$lblSecondary.AutoSize = $true
$customPanel.Controls.Add($lblSecondary)

$txtSecondary = New-Object System.Windows.Forms.TextBox
$txtSecondary.Location = New-Object System.Drawing.Point(100, 65)
$txtSecondary.Size = New-Object System.Drawing.Size(200, 25)
$txtSecondary.BackColor = $buttonColor
$txtSecondary.ForeColor = $textColor
$txtSecondary.BorderStyle = "FixedSingle"
$txtSecondary.Font = New-Object System.Drawing.Font("Consolas", 10)
$customPanel.Controls.Add($txtSecondary)

$btnApplyCustom = New-Object System.Windows.Forms.Button
$btnApplyCustom.Text = "Apply Custom DNS"
$btnApplyCustom.Location = New-Object System.Drawing.Point(10, 105)
$btnApplyCustom.Size = New-Object System.Drawing.Size(290, 35)
$btnApplyCustom.BackColor = [System.Drawing.Color]::FromArgb(0, 100, 180)
$btnApplyCustom.ForeColor = $textColor
$btnApplyCustom.FlatStyle = "Flat"
$btnApplyCustom.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnApplyCustom.Cursor = "Hand"
$customPanel.Controls.Add($btnApplyCustom)

$btnPingCustom = New-Object System.Windows.Forms.Button
$btnPingCustom.Text = "Ping Custom DNS"
$btnPingCustom.Location = New-Object System.Drawing.Point(10, 145)
$btnPingCustom.Size = New-Object System.Drawing.Size(290, 35)
$btnPingCustom.BackColor = $buttonColor
$btnPingCustom.ForeColor = $textColor
$btnPingCustom.FlatStyle = "Flat"
$btnPingCustom.Cursor = "Hand"
$customPanel.Controls.Add($btnPingCustom)

# Tools Panel
$toolsPanel = New-Object System.Windows.Forms.Panel
$toolsPanel.Location = New-Object System.Drawing.Point(20, 375)
$toolsPanel.Size = New-Object System.Drawing.Size(645, 50)
$toolsPanel.BackColor = $panelColor
$form.Controls.Add($toolsPanel)

$btnFlushDNS = New-Object System.Windows.Forms.Button
$btnFlushDNS.Text = "Flush DNS Cache"
$btnFlushDNS.Location = New-Object System.Drawing.Point(10, 8)
$btnFlushDNS.Size = New-Object System.Drawing.Size(150, 32)
$btnFlushDNS.BackColor = $buttonColor
$btnFlushDNS.ForeColor = $textColor
$btnFlushDNS.FlatStyle = "Flat"
$btnFlushDNS.Cursor = "Hand"
$toolsPanel.Controls.Add($btnFlushDNS)

$btnSpeedTest = New-Object System.Windows.Forms.Button
$btnSpeedTest.Text = "Speed Test"
$btnSpeedTest.Location = New-Object System.Drawing.Point(170, 8)
$btnSpeedTest.Size = New-Object System.Drawing.Size(150, 32)
$btnSpeedTest.BackColor = [System.Drawing.Color]::FromArgb(100, 50, 150)
$btnSpeedTest.ForeColor = $textColor
$btnSpeedTest.FlatStyle = "Flat"
$btnSpeedTest.Cursor = "Hand"
$toolsPanel.Controls.Add($btnSpeedTest)

$btnPingAll = New-Object System.Windows.Forms.Button
$btnPingAll.Text = "Benchmark All DNS"
$btnPingAll.Location = New-Object System.Drawing.Point(330, 8)
$btnPingAll.Size = New-Object System.Drawing.Size(150, 32)
$btnPingAll.BackColor = [System.Drawing.Color]::FromArgb(50, 100, 150)
$btnPingAll.ForeColor = $textColor
$btnPingAll.FlatStyle = "Flat"
$btnPingAll.Cursor = "Hand"
$toolsPanel.Controls.Add($btnPingAll)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Refresh"
$btnRefresh.Location = New-Object System.Drawing.Point(490, 8)
$btnRefresh.Size = New-Object System.Drawing.Size(140, 32)
$btnRefresh.BackColor = $buttonColor
$btnRefresh.ForeColor = $textColor
$btnRefresh.FlatStyle = "Flat"
$btnRefresh.Cursor = "Hand"
$toolsPanel.Controls.Add($btnRefresh)

# Output Panel
$outputPanel = New-Object System.Windows.Forms.Panel
$outputPanel.Location = New-Object System.Drawing.Point(20, 435)
$outputPanel.Size = New-Object System.Drawing.Size(645, 190)
$outputPanel.BackColor = $panelColor
$form.Controls.Add($outputPanel)

$lblOutputTitle = New-Object System.Windows.Forms.Label
$lblOutputTitle.Text = "Output Log"
$lblOutputTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblOutputTitle.ForeColor = $textColor
$lblOutputTitle.Location = New-Object System.Drawing.Point(10, 8)
$lblOutputTitle.AutoSize = $true
$outputPanel.Controls.Add($lblOutputTitle)

$btnClearLog = New-Object System.Windows.Forms.Button
$btnClearLog.Text = "Clear"
$btnClearLog.Location = New-Object System.Drawing.Point(580, 5)
$btnClearLog.Size = New-Object System.Drawing.Size(55, 22)
$btnClearLog.BackColor = $buttonColor
$btnClearLog.ForeColor = $textColor
$btnClearLog.FlatStyle = "Flat"
$btnClearLog.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$btnClearLog.Cursor = "Hand"
$outputPanel.Controls.Add($btnClearLog)

$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Location = New-Object System.Drawing.Point(10, 32)
$txtOutput.Size = New-Object System.Drawing.Size(625, 150)
$txtOutput.Multiline = $true
$txtOutput.ScrollBars = "Vertical"
$txtOutput.ReadOnly = $true
$txtOutput.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 30)
$txtOutput.ForeColor = [System.Drawing.Color]::LightGreen
$txtOutput.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtOutput.BorderStyle = "FixedSingle"
$outputPanel.Controls.Add($txtOutput)

# ============================================
# FUNCTIONS - Update UI
# ============================================

function Update-CurrentDNS {
    $current = Get-CurrentDNS
    if ($current) {
        $lblAdapter.Text = "Adapter: $($current.AdapterName)"
        if ($current.DNS) {
            $lblCurrentDNS.Text = "DNS: $($current.DNS)"
        }
        else {
            $lblCurrentDNS.Text = "DNS: Automatic (DHCP)"
        }
    }
    else {
        $lblAdapter.Text = "Adapter: No active adapter found"
        $lblCurrentDNS.Text = "DNS: N/A"
    }
}

function Update-PresetDNSLabel {
    $selected = $cmbPresets.SelectedItem
    if ($selected -and $script:DNSPresets.Contains($selected)) {
        $dns = $script:DNSPresets[$selected]
        $lblPresetDNS.Text = "$($dns[0]) | $($dns[1])"
    }
}

function Log-Message {
    param([string]$Message)
    $timestamp = Get-Date -Format "HH:mm:ss"
    $txtOutput.AppendText("[$timestamp] $Message`r`n")
    $txtOutput.ScrollToCaret()
}

# ============================================
# EVENT HANDLERS
# ============================================

$cmbPresets.Add_SelectedIndexChanged({ Update-PresetDNSLabel })

$btnApplyPreset.Add_Click({
        $selected = $cmbPresets.SelectedItem
        if ($selected -and $script:DNSPresets.Contains($selected)) {
            $dns = $script:DNSPresets[$selected]
            Log-Message "Applying $selected DNS..."
            $result = Set-DNSServers -Primary $dns[0] -Secondary $dns[1]
            if ($result) {
                Log-Message "[OK] Successfully applied $selected DNS ($($dns[0]), $($dns[1]))"
                Update-CurrentDNS
            }
            else {
                Log-Message "[ERROR] Failed to apply DNS. Make sure you run as Administrator."
            }
        }
    })

$btnPingPreset.Add_Click({
        $selected = $cmbPresets.SelectedItem
        if ($selected -and $script:DNSPresets.Contains($selected)) {
            $dns = $script:DNSPresets[$selected][0]
            Log-Message "Pinging $selected ($dns)..."
            [System.Windows.Forms.Application]::DoEvents()
            $result = Test-DNSPing -DNS $dns
            if ($result.Success) {
                Log-Message "[OK] $selected - Avg: $($result.Average)ms, Min: $($result.Min)ms, Max: $($result.Max)ms"
            }
            else {
                Log-Message "[FAIL] $selected - Ping failed"
            }
        }
    })

$btnResetDNS.Add_Click({
        Log-Message "Resetting DNS to Automatic (DHCP)..."
        $result = Reset-DNSToAuto
        if ($result) {
            Log-Message "[OK] DNS reset to Automatic (DHCP)"
            Update-CurrentDNS
        }
        else {
            Log-Message "[ERROR] Failed to reset DNS"
        }
    })

$btnApplyCustom.Add_Click({
        $primary = $txtPrimary.Text.Trim()
        $secondary = $txtSecondary.Text.Trim()
    
        if ([string]::IsNullOrEmpty($primary)) {
            Log-Message "[ERROR] Primary DNS is required"
            return
        }
    
        # Validate IP format
        try {
            [System.Net.IPAddress]::Parse($primary) | Out-Null
            if ($secondary) {
                [System.Net.IPAddress]::Parse($secondary) | Out-Null
            }
        }
        catch {
            Log-Message "[ERROR] Invalid IP address format"
            return
        }
    
        Log-Message "Applying custom DNS ($primary, $secondary)..."
        $result = Set-DNSServers -Primary $primary -Secondary $secondary
        if ($result) {
            Log-Message "[OK] Successfully applied custom DNS"
            Update-CurrentDNS
        }
        else {
            Log-Message "[ERROR] Failed to apply DNS"
        }
    })

$btnPingCustom.Add_Click({
        $primary = $txtPrimary.Text.Trim()
        if ([string]::IsNullOrEmpty($primary)) {
            Log-Message "[ERROR] Enter a DNS address to ping"
            return
        }
    
        Log-Message "Pinging $primary..."
        [System.Windows.Forms.Application]::DoEvents()
        $result = Test-DNSPing -DNS $primary
        if ($result.Success) {
            Log-Message "[OK] $primary - Avg: $($result.Average)ms, Min: $($result.Min)ms, Max: $($result.Max)ms"
        }
        else {
            Log-Message "[FAIL] $primary - Ping failed"
        }
    })

$btnFlushDNS.Add_Click({
        Log-Message "Flushing DNS cache..."
        try {
            Clear-DnsClientCache
            Log-Message "[OK] DNS cache flushed successfully"
        }
        catch {
            Log-Message "[ERROR] Failed to flush DNS cache"
        }
    })

$btnSpeedTest.Add_Click({
        Start-SpeedTest -OutputBox $txtOutput
    })

$btnPingAll.Add_Click({
        Log-Message "Benchmarking all DNS servers..."
        Log-Message ("-" * 50)
        [System.Windows.Forms.Application]::DoEvents()
    
        $results = @()
        foreach ($preset in $script:DNSPresets.GetEnumerator()) {
            $dns = $preset.Value[0]
            $result = Test-DNSPing -DNS $dns
            if ($result.Success) {
                $results += @{
                    Name = $preset.Key
                    DNS  = $dns
                    Avg  = $result.Average
                }
                Log-Message "$($preset.Key.PadRight(15)) | $dns | Avg: $($result.Average)ms"
            }
            else {
                Log-Message "$($preset.Key.PadRight(15)) | $dns | Failed"
            }
            [System.Windows.Forms.Application]::DoEvents()
        }
    
        Log-Message ("-" * 50)
    
        if ($results.Count -gt 0) {
            $fastest = $results | Sort-Object { $_.Avg } | Select-Object -First 1
            Log-Message "[BEST] Fastest DNS: $($fastest.Name) ($($fastest.DNS)) - $($fastest.Avg)ms"
        }
    })

$btnRefresh.Add_Click({
        Update-CurrentDNS
        Log-Message "[OK] Status refreshed"
    })

$btnClearLog.Add_Click({
        $txtOutput.Clear()
    })

# ============================================
# INITIALIZE
# ============================================

Update-CurrentDNS
Update-PresetDNSLabel
Log-Message "DNS Manager initialized"
Log-Message "Active adapter: $($lblAdapter.Text -replace 'Adapter: ', '')"

# Show form - This keeps the window open
[System.Windows.Forms.Application]::Run($form)
