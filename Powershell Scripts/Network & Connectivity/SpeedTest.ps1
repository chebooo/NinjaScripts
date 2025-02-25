[CmdletBinding()]
param (
    [Parameter()]
    [String]$OoklaSpeedtestURI = 'https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win64.zip',
    [Parameter()]
    [String]$OoklaSpeedtestEXEPath = "$env:ProgramData\SpeedTest\",
    [Parameter()]
    [Switch]$NoUpdate,
    [Parameter()]
    [Switch]$ForceUpdate,
    [Parameter()]
    [String]$CLISwitches
)

# Create results directory
$ResultsPath = "$env:ProgramData\SpeedTest\Results"
if (-not (Test-Path $ResultsPath)) {
    New-Item -ItemType Directory -Path $ResultsPath -Force
}

$OoklaSpeedtestZipName = Split-Path -Path $OoklaSpeedtestURI -Leaf
$OoklaSpeedtestZipPath = Join-Path -Path $OoklaSpeedtestEXEPath -ChildPath $OoklaSpeedtestZipName
$OoklaSpeedtestEXEFile = Join-Path -Path $OoklaSpeedtestEXEPath -ChildPath 'speedtest.exe'

# Download and extract if needed
if (-not (Test-Path $OoklaSpeedtestEXEFile) -or $ForceUpdate) {
    Write-Host "Downloading Ookla Speedtest CLI..."
    Invoke-WebRequest -Uri $OoklaSpeedtestURI -OutFile $OoklaSpeedtestZipPath -UseBasicParsing
    if (Test-Path -Path $OoklaSpeedtestZipPath) {
        Write-Host "Extracting $OoklaSpeedtestZipName..."
        Expand-Archive -Path $OoklaSpeedtestZipPath -DestinationPath $OoklaSpeedtestEXEPath -Force
    } else {
        Write-Error 'Failed to download latest Ookla Speedtest CLI.'
        exit 1
    }
}

# Run speed test
Write-Host "Running speed test..."
try {
    # Build arguments array
    $arguments = @('--format=json', '--accept-license', '--accept-gdpr')
    if (-not [String]::IsNullOrWhiteSpace($CLISwitches)) {
        $arguments += $CLISwitches.Split(' ')
    }
    
    # Run speedtest with arguments
    $SpeedTestResultJSON = & $OoklaSpeedtestEXEFile $arguments
    
    if ([string]::IsNullOrWhiteSpace($SpeedTestResultJSON)) {
        throw "Speedtest execution returned no results"
    }
    
    $SpeedTestResult = $SpeedTestResultJSON | ConvertFrom-Json
} catch {
    Write-Error "Failed to run speedtest: $_"
    exit 1
}

# Calculate results
$ServerUsed = if ($SpeedTestResult.server) {
    '{0} ({1} - {2})' -f $SpeedTestResult.server.name, $SpeedTestResult.server.location, $SpeedTestResult.server.country
} else { "No server information" }

$DownloadSpeed = if ($SpeedTestResult.download.bandwidth) {
    [math]::Round($SpeedTestResult.download.bandwidth / 125000, 2)
} else { 0 }

$UploadSpeed = if ($SpeedTestResult.upload.bandwidth) {
    [math]::Round($SpeedTestResult.upload.bandwidth / 125000, 2)
} else { 0 }

# Update NinjaRMM custom fields using exact field names from configuration
try {
    Ninja-Property-Set "serverUsed" $ServerUsed
    Ninja-Property-Set "downloadSpeed" $DownloadSpeed
    Ninja-Property-Set "uploadSpeed" $UploadSpeed
    
    Write-Host "Successfully updated NinjaRMM custom fields" -ForegroundColor Green
} catch {
    Write-Error "Failed to update NinjaRMM custom fields: $_"
}

# Save results to file (for logging)
$ResultsFile = Join-Path -Path $ResultsPath -ChildPath "speedtest_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$Results = [PSCustomObject]@{
    Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    ServerUsed = $ServerUsed
    DownloadSpeed = $DownloadSpeed
    UploadSpeed = $UploadSpeed
    Latency = $SpeedTestResult.ping.latency
    PacketLoss = $SpeedTestResult.packetLoss
}
$Results | ConvertTo-Json | Out-File -FilePath $ResultsFile

# Display results
Write-Host "`nSpeed Test Results:" -ForegroundColor Green
Write-Host "Server Used: $ServerUsed"
Write-Host "Download Speed: $DownloadSpeed Mbps"
Write-Host "Upload Speed: $UploadSpeed Mbps"
Write-Host "Latency: $($SpeedTestResult.ping.latency) ms"
Write-Host "Results saved to: $ResultsFile"