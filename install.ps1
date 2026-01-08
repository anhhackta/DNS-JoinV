# DNS JoinV - Quick Installer
# Run: irm https://anhhackta.github.io/DNS-JoinV/install.ps1 | iex

# Check & Request Admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    $scriptUrl = "https://anhhackta.github.io/DNS-JoinV/install.ps1"
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm '$scriptUrl' | iex`"" -Verb RunAs
    exit
}

# Download DNS-JoinV.cmd
Write-Host "Downloading DNS JoinV..." -ForegroundColor Green
$downloadUrl = "https://anhhackta.github.io/DNS-JoinV/DNS-JoinV.cmd"
$outputPath = Join-Path $env:TEMP "DNS-JoinV.cmd"

try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $outputPath -UseBasicParsing
    Write-Host "Download complete! Launching DNS JoinV..." -ForegroundColor Green
    Start-Process -FilePath $outputPath -Wait
    Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
}
