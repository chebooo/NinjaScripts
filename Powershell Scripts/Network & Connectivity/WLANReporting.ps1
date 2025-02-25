try {
    # Default WLAN report path
    $reportPath = "$env:ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html"
    
    # Generate a new WLAN report
    Write-Host "Generating new WLAN report..."
    $generateResult = netsh wlan show wlanreport
    
    # Wait a moment for the report to be created
    Start-Sleep -Seconds 3
    
    # Check if file exists and is recent
    if (Test-Path $reportPath) {
        $reportFile = Get-Item $reportPath
        if ($reportFile.LastWriteTime -gt (Get-Date).AddMinutes(-5)) {
            Write-Host "Healthy - Latest report can be found at $reportPath"
        } else {
            Write-Host "Report exists but wasn't just created. Last modified: $($reportFile.LastWriteTime)"
            Write-Host "Command output was: $generateResult"
            exit 1
        }
    } else {
        # Try to find the report in case it's in a different location
        Write-Host "Looking for WLAN report files..."
        $possibleReports = Get-ChildItem -Path "$env:ProgramData\Microsoft\Windows\WlanReport\" -Filter "*.html" -ErrorAction SilentlyContinue |
                          Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        if ($possibleReports) {
            Write-Host "Found recent report at: $($possibleReports.FullName)"
        } else {
            throw "Could not generate or find WLAN report. Command output: $generateResult"
        }
    }
}
catch {
    Write-Host "Error with WLAN report: $($_.Exception.Message)"
    Write-Host "Please ensure you're running this script as Administrator and that the device has a wireless adapter."
    exit 1
}