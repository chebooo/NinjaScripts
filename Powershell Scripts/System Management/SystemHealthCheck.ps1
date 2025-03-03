# Also output summary to console
Write-Host ""
Write-Host "System Health Check Summary:"
Write-Host "-------------------------"
Write-Host "SFC: $sfcResult"
Write-Host "DISM: $dismResultText" 
Write-Host "CHKDSK: " -NoNewline
if ($anyChkdskErrors) {
    Write-Host "Issues detected" -ForegroundColor Red
} else {
    Write-Host "No issues detected" -ForegroundColor Green
}
Write-Host "-------------------------"
Write-Host "$summaryText"# Run the System File Checker
Write-Output "Running SFC..."
$sfcOutput = & {
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo.FileName = "sfc.exe"
    $process.StartInfo.Arguments = "/scannow"
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.Start()
    $output = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()
    $output
}

# Check the SFC output for errors and extract details
$sfcErrorFound = $false
$sfcErrorDetails = ""

if ($sfcOutput -match "Windows Resource Protection found corrupt files") {
    # Extract specific error information
    $errorLines = $sfcOutput -split "`n" | Where-Object { $_ -match "corrupt|cannot repair|could not" }
    $sfcErrorDetails = $errorLines -join "<br>"
    $sfcResult = "Errors found, Action required"
    $sfcIcon = "⛔"
    $sfcErrorFound = $true
    Write-Host "Windows Resource Protection found corrupt files"
} elseif ($sfcOutput -match "Windows Resource Protection found corrupt files and successfully repaired them") {
    $sfcErrorDetails = "The following system files were corrupted and have been successfully repaired:<br>"
    # Try to extract file names that were repaired
    $repairedFiles = $sfcOutput -split "`n" | Where-Object { $_ -match "\\windows\\|\.dll|\.sys|\.exe" }
    if ($repairedFiles) {
        $sfcErrorDetails += ($repairedFiles -join "<br>")
    } else {
        $sfcErrorDetails += "Windows system files (specific files not identified in the log)"
    }
    $sfcResult = "Errors found and repaired"
    $sfcIcon = "⚠️"
    $sfcErrorFound = $true
    Write-Host "Windows Resource Protection found and repaired corrupt files"
} else {
    $sfcResult = "No errors found"
    $sfcIcon = "✅"
    Write-Host "Windows Resource Protection did not find any integrity violations"
}

# Create initial HTML content for SFC
$htmlContent = @"
    <table border='0'>
        <tr>
            <th style='width: 250px;'>$sfcIcon SFC</th>
            <td>$sfcResult</td>
        </tr>
"@

# Add error details if available
if ($sfcErrorDetails) {
    $htmlContent += @"
        <tr>
            <td colspan='2' style='color: red; padding-left: 20px;'>$sfcErrorDetails</td>
        </tr>
"@
}

$htmlContent += @"
    </table>
"@

# Output initial HTML content to a file
Ninja-Property-Set SystemHealthCheck $htmlContent

# Run DISM to repair Windows image
Write-Output "Running DISM..."
$dismCheckHealth = dism /Online /Cleanup-Image /CheckHealth
$dismScanHealth = dism /Online /Cleanup-Image /ScanHealth
$dismRestoreHealth = dism /Online /Cleanup-Image /RestoreHealth

# Extract DISM error details
$dismErrorFound = $false
$dismErrorDetails = ""

if ($dismRestoreHealth -match "Error") {
    $errorLines = $dismRestoreHealth -split "`n" | Where-Object { $_ -match "Error|Failed|Cannot" }
    $dismErrorDetails = $errorLines -join "<br>"
    $dismResultText = "Errors found, Manual action required"
    $dismIcon = "⛔"
    $dismErrorFound = $true
} elseif ($dismRestoreHealth -match "The restore operation completed successfully") {
    $dismErrorDetails = "DISM found and repaired corruptions in the Windows component store.<br>"
    # Try to extract more details about what was fixed
    $componentDetails = $dismRestoreHealth -split "`n" | Where-Object { $_ -match "repair|corrupt|component|restore" }
    if ($componentDetails) {
        $dismErrorDetails += ($componentDetails | Select-Object -First 5) -join "<br>"
    } else {
        $dismErrorDetails += "Component store integrity was restored. This improves system stability and helps prevent application failures."
    }
    $dismResultText = "Errors found and repaired"
    $dismIcon = "⚠️"
    $dismErrorFound = $true
} else {
    $dismResultText = "No errors found"
    $dismIcon = "✅"
}

$lastTwoLines = $dismRestoreHealth -split "`n" | Select-Object -Last 2

# Output the last 2 lines
Write-Host $lastTwoLines

# Append DISM result to HTML content
$htmlContent += @"
    <table border='0'>
        <tr>
            <th style='width: 250px;'>$dismIcon DISM</th>
            <td>$dismResultText</td>
        </tr>
"@

# Add DISM error details if available
if ($dismErrorDetails) {
    $htmlContent += @"
        <tr>
            <td colspan='2' style='color: red; padding-left: 20px;'>$dismErrorDetails</td>
        </tr>
"@
}

$htmlContent += @"
    </table>
"@

# Output updated HTML content to a file
Ninja-Property-Set SystemHealthCheck $htmlContent

# Run Check Disk on all disks
Write-Output "Running Check Disk on all disks..."

# Get all disks
$disks = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3"

# Initialize a list to store results for all drives
$chkdskResults = @()
$chkdskErrorDetails = @()
$anyChkdskErrors = $false

# Loop through each disk and run chkdsk
foreach ($disk in $disks) {
    $driveLetter = $disk.DeviceID
    Write-Output "Running chkdsk on $driveLetter"
    
    $chkdskOutput = & {
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo.FileName = "chkdsk.exe"
        $process.StartInfo.Arguments = "$driveLetter /scan"
        $process.StartInfo.RedirectStandardOutput = $true
        $process.StartInfo.UseShellExecute = $false
        $process.StartInfo.CreateNoWindow = $true
        $process.Start()
        $output = $process.StandardOutput.ReadToEnd()
        $process.WaitForExit()
        $output
    }

    # Get disk information using WMI instead of parsing CHKDSK output
    # This is more reliable than trying to parse the text output
    $diskInfo = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$driveLetter'"
    
    # Set default values
    $badSectors = "0"
    $allocationUnitSize = $diskInfo.BlockSize
    if (-not $allocationUnitSize) { $allocationUnitSize = "4096" } # Default if not available
    $totalUnits = [math]::Floor($diskInfo.Size / $allocationUnitSize)
    $availableUnits = [math]::Floor($diskInfo.FreeSpace / $allocationUnitSize)
    
    # Calculate disk space in GB if we have the data
    $totalSpaceGB = "Unknown"
    $freeSpaceGB = "Unknown"
    $freeSpacePercent = "Unknown"
    
    if ($allocationUnitSize -ne "Unknown" -and $totalUnits -ne "Unknown" -and $availableUnits -ne "Unknown") {
        $allocationSizeBytes = [double]$allocationUnitSize
        $totalAllocationUnits = [double]$totalUnits
        $availableAllocationUnits = [double]$availableUnits
        
        $totalSpaceBytes = $allocationSizeBytes * $totalAllocationUnits
        $freeSpaceBytes = $allocationSizeBytes * $availableAllocationUnits
        
        $totalSpaceGB = [math]::Round($totalSpaceBytes / 1GB, 2)
        $freeSpaceGB = [math]::Round($freeSpaceBytes / 1GB, 2)
        $freeSpacePercent = [math]::Round(($availableAllocationUnits / $totalAllocationUnits) * 100, 1)
    }
    
    # Format disk statistics as a readable HTML table
    $diskStats = @"
<table class='disk-stats' style='margin-left: 20px; border-collapse: collapse; width: 80%;'>
    <tr style='background-color: #f8f8f8;'>
        <td style='padding: 2px 10px; width: 200px;'>Bad sectors:</td>
        <td style='padding: 2px 10px;'>$badSectors KB</td>
    </tr>
    <tr>
        <td style='padding: 2px 10px;'>Allocation unit size:</td>
        <td style='padding: 2px 10px;'>$allocationUnitSize bytes</td>
    </tr>
    <tr style='background-color: #f8f8f8;'>
        <td style='padding: 2px 10px;'>Total space:</td>
        <td style='padding: 2px 10px;'>$totalSpaceGB GB ($totalUnits units)</td>
    </tr>
    <tr>
        <td style='padding: 2px 10px;'>Free space:</td>
        <td style='padding: 2px 10px;'>$freeSpaceGB GB ($freeSpacePercent%)</td>
    </tr>
</table>
"@

    # Check for errors in CHKDSK output
    if ($chkdskOutput -match "found problems|errors found|corrupted file|invalid|Unrecoverable") {
        $chkdskResult = "Errors found on $driveLetter, Action required"
        $chkdskIcon = "⛔"
        $chkdskErrorDetails += "$driveLetter drive health check:<br>$diskStats"
        $anyChkdskErrors = $true
        Write-Host "Errors found on $driveLetter"
    } else {
        $chkdskResult = "No errors found on $driveLetter"
        $chkdskIcon = "✅"
        # Still add the disk statistics even when no errors are found
        $chkdskErrorDetails += "$driveLetter drive statistics:<br>$diskStats"
        Write-Host "No errors found on $driveLetter"
    }

    # Add the result to the list
    $chkdskResults += "$chkdskResult"
}

# Join all results into a single string
$chkdskResultsText = $chkdskResults -join "<br>"

# Append CHKDSK results to HTML content
$htmlContent += @"
    <table border='0'>
        <tr>
            <th style='width: 250px;'>$chkdskIcon CHKDSK</th>
            <td>$chkdskResultsText</td>
        </tr>
"@

# Add disk statistics for all drives
$chkdskErrorDetailsText = $chkdskErrorDetails -join "<br><br>"
$htmlContent += @"
    <tr>
        <td colspan='2' style='padding-left: 0px;'>$chkdskErrorDetailsText</td>
    </tr>
"@

$htmlContent += @"
    </table>
"@

# Create a detailed extended summary section
$extendedSummary = "<h3>Extended Health Check Analysis</h3>"

# Add an overall assessment
if ($totalIssues -eq 0) {
    $extendedSummary += "<p>Your system appears to be in <strong>excellent health</strong>. All system integrity checks passed successfully.</p>"
} elseif ($totalIssues -eq 1 -and ($dismResultText -match "repaired" -or $sfcResult -match "repaired")) {
    $extendedSummary += "<p>Your system appears to be in <strong>good health</strong>. Minor issues were detected but were automatically repaired.</p>"
} else {
    $extendedSummary += "<p>Your system requires <strong>attention</strong>. Several issues were detected during the health check.</p>"
}

# Add section about SFC
$extendedSummary += "<h4>System File Checker (SFC)</h4>"
if ($sfcResult -eq "No errors found") {
    $extendedSummary += "<p>✅ All Windows system files are intact and uncorrupted.</p>"
} elseif ($sfcResult -match "repaired") {
    $extendedSummary += "<p>⚠️ SFC found and repaired corrupted system files. This indicates your system experienced some integrity issues that have now been fixed.</p>"
    if ($sfcErrorDetails) {
        $extendedSummary += "<p>Details: $sfcErrorDetails</p>"
    }
} else {
    $extendedSummary += "<p>⛔ SFC found system file corruption that could not be automatically repaired. This may cause system instability, application crashes, or boot failures.</p>"
    if ($sfcErrorDetails) {
        $extendedSummary += "<p>Details: $sfcErrorDetails</p>"
    }
    $extendedSummary += "<p>Recommended action: Try running DISM with the /RestoreHealth option, then run SFC again.</p>"
}

# Add section about DISM
$extendedSummary += "<h4>Deployment Image Servicing and Management (DISM)</h4>"
if ($dismResultText -eq "No errors found") {
    $extendedSummary += "<p>✅ The Windows component store is healthy.</p>"
} elseif ($dismResultText -match "repaired") {
    $extendedSummary += "<p>⚠️ DISM found and repaired corruption in the Windows component store. This is helpful for system stability.</p>"
    if ($dismErrorDetails) {
        $extendedSummary += "<p>Details: $dismErrorDetails</p>"
    }
} else {
    $extendedSummary += "<p>⛔ DISM found component store corruption that could not be automatically repaired.</p>"
    if ($dismErrorDetails) {
        $extendedSummary += "<p>Details: $dismErrorDetails</p>"
    }
    $extendedSummary += "<p>Recommended action: Try running Windows Update to download fresh system files, or consider a system reset if problems persist.</p>"
}

# Add section about CHKDSK
$extendedSummary += "<h4>Check Disk (CHKDSK)</h4>"
if ($anyChkdskErrors) {
    $extendedSummary += "<p>⛔ Disk errors were detected on one or more drives. This may indicate hardware issues or filesystem corruption.</p>"
    $extendedSummary += "<p>Recommended action: Run a full CHKDSK with repairs using 'chkdsk /f /r' on the affected drives. Consider backing up important data.</p>"
} else {
    $extendedSummary += "<p>✅ No disk errors were detected. Your storage drives appear to be healthy.</p>"
}

# Add disk space warning if applicable
foreach ($disk in $disks) {
    $driveLetter = $disk.DeviceID
    $totalSpace = [math]::Round($disk.Size / 1GB, 2)
    $freeSpace = [math]::Round($disk.FreeSpace / 1GB, 2)
    $freePercent = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 1)
    
    if ($freePercent -lt 10) {
        $extendedSummary += "<p>⚠️ <strong>Low disk space warning</strong>: $driveLetter has only $freePercent% free space ($freeSpace GB free of $totalSpace GB).</p>"
        $extendedSummary += "<p>Recommended action: Free up space by removing unnecessary files, uninstalling unused programs, or moving data to external storage.</p>"
    }
}

# Add section for recommendations
$extendedSummary += "<h4>Recommendations</h4>"
$extendedSummary += "<ul>"

if ($sfcErrorFound -or $dismErrorFound) {
    $extendedSummary += "<li>Schedule regular system maintenance to prevent system file corruption</li>"
    $extendedSummary += "<li>Consider checking for malware, as it can sometimes cause system file corruption</li>"
}

if ($anyChkdskErrors) {
    $extendedSummary += "<li>Monitor your hard drives for further errors - recurring issues may indicate drive failure</li>"
    $extendedSummary += "<li>Ensure important data is backed up regularly</li>"
}

$extendedSummary += "<li>Keep Windows updated to prevent security vulnerabilities</li>"
$extendedSummary += "</ul>"

# Add the extended summary to HTML content
$htmlContent += @"
    <br>
    <div style='background-color: #f9f9f9; padding: 10px; border: 1px solid #ddd; margin-top: 20px;'>
        $extendedSummary
    </div>
"@

# Output final HTML content to a file
Ninja-Property-Set SystemHealthCheck $htmlContent

# Create a summary section
$totalIssues = 0
$totalIssues += if ($sfcResult -match "Errors found") { 1 } else { 0 }
$totalIssues += if ($dismResultText -match "Errors found") { 1 } else { 0 }
$totalIssues += if ($anyChkdskErrors) { 1 } else { 0 }

$summaryIcon = if ($totalIssues -gt 0) { "⚠️" } else { "✅" }
$summaryText = if ($totalIssues -gt 0) { "$totalIssues system component(s) reported issues" } else { "All system components are healthy" }

$htmlContent += @"
    <table border='0'>
        <tr>
            <th style='width: 250px; background-color: #f0f0f0;'>$summaryIcon SUMMARY</th>
            <td style='background-color: #f0f0f0; font-weight: bold;'>$summaryText</td>
        </tr>
    </table>
"@


