# DNS JoinV - Quick Installer
# Run: irm https://anhhackta.github.io/DNS-JoinV/install.ps1 | iex

# Check & Request Admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm 'https://anhhackta.github.io/DNS-JoinV/install.ps1' | iex`"" -Verb RunAs
    exit
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "  DNS JoinV - Quick Installer  " -ForegroundColor Green
Write-Host "================================`n" -ForegroundColor Cyan

# Download DNS-JoinV.cmd
Write-Host "[1/2] Downloading..." -ForegroundColor Yellow
$downloadUrl = "https://anhhackta.github.io/DNS-JoinV/DNS-JoinV.cmd"
$outputPath = Join-Path $env:TEMP "DNS-JoinV.cmd"

try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $outputPath -UseBasicParsing
    Write-Host "[2/2] Launching DNS JoinV..." -ForegroundColor Yellow
    
    # Schedule cleanup task for temp file
    Start-Job -ScriptBlock { 
        Start-Sleep -Seconds 5
        Remove-Item -Path $args[0] -Force -ErrorAction SilentlyContinue 
    } -ArgumentList $outputPath | Out-Null
    
    # Launch GUI
    Start-Process -FilePath $outputPath
    
    Write-Host "DNS JoinV is now running!`n" -ForegroundColor Green
    
    # Exit immediately to close PowerShell window
    exit
}
catch {
    Write-Host "`n[ERROR] Failed to download or launch DNS JoinV" -ForegroundColor Red
    Write-Host "Error: $_`n" -ForegroundColor Red
    Read-Host "Press Enter to exit"
}
