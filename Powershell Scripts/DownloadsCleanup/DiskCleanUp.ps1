# Downloads Folder Cleanup Script with Built-in Notifications
# Enhanced with detailed size reporting

# Exit if running as SYSTEM (no standard Downloads folder)
If( ([System.Security.Principal.WindowsIdentity]::GetCurrent()).Name -eq 'NT AUTHORITY\SYSTEM') {
    Write-Host "Exiting: SYSTEM user not supported."
    Exit 1
}

# Configurable Settings
$KillAge = -60  # Delete files older than 60 days
$ShameThreshold = 90  # Disk usage warning threshold
$TrimPath = "$($env:USERPROFILE)\Downloads"
$MsgTitle = "Downloads Cleanup"
$LogFile = "$env:TEMP\DownloadsCleanup.log"

# Function to format file size in a human-readable format
function Format-FileSize {
    param ([long]$Size)
    
    if ($Size -ge 1TB) { return "{0:N2} TB" -f ($Size / 1TB) }
    if ($Size -ge 1GB) { return "{0:N2} GB" -f ($Size / 1GB) }
    if ($Size -ge 1MB) { return "{0:N2} MB" -f ($Size / 1MB) }
    if ($Size -ge 1KB) { return "{0:N2} KB" -f ($Size / 1KB) }
    return "$Size Bytes"
}

# Function to log messages
function Write-Log {
    param (
        [string]$Message
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$TimeStamp - $Message" | Out-File -FilePath $LogFile -Append
    Write-Host "$TimeStamp - $Message"
}

# Function to show notification using built-in Windows capabilities
function Show-Notification {
    param (
        [string]$Title,
        [string]$Message
    )
    
    try {
        # Log the notification message anyway
        Write-Log "$Title - $Message"
        
        # Try to show notification using built-in Windows method
        Add-Type -AssemblyName System.Windows.Forms
        $notification = New-Object System.Windows.Forms.NotifyIcon
        $notification.Icon = [System.Drawing.SystemIcons]::Information
        $notification.BalloonTipTitle = $Title
        $notification.BalloonTipText = $Message
        $notification.Visible = $true
        $notification.ShowBalloonTip(5000) # Show for 5 seconds
        
        # Sleep to allow notification to display before continuing
        Start-Sleep -Seconds 1
    }
    catch {
        Write-Log "Could not display notification: $_"
    }
}

# Start the log
Write-Log "Starting Downloads cleanup process"

# Get initial folder size
$InitialFolderSize = (Get-ChildItem $TrimPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
$InitialFolderSizeFormatted = Format-FileSize -Size $InitialFolderSize
Write-Log "Initial Downloads folder size: $InitialFolderSizeFormatted"

# Identify Files to Delete
$KillList = Get-ChildItem $TrimPath -Recurse | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays($KillAge) }

# Notify if No Files Found
If (-not $KillList) {
    Show-Notification $MsgTitle "No files older than $([Math]::Abs($KillAge)) days"
    Exit 0
}

# Calculate size of files to be deleted
$FilesToDeleteSize = ($KillList | Measure-Object -Property Length -Sum).Sum
$FilesToDeleteSizeFormatted = Format-FileSize -Size $FilesToDeleteSize
$FilesToDeletePercentage = [math]::Round(($FilesToDeleteSize / $InitialFolderSize) * 100, 1)

# Gather Storage Stats
try {
    $OSVol = Get-WMIObject Win32_Volume | Where-Object { $_.DriveLetter -eq ($env:SystemDrive) }
    $UsedSpace = [math]::round(($OSVol.Capacity - $OSVol.FreeSpace) / $OSVol.Capacity * 100, 1)
    $DlCount = $KillList.Count
    
    # Log detailed information
    Write-Log "Found $DlCount files older than $([Math]::Abs($KillAge)) days"
    Write-Log "Files to delete size: $FilesToDeleteSizeFormatted ($FilesToDeletePercentage% of Downloads folder)"
    Write-Log "System drive usage: $UsedSpace%"
    
    $NotificationText = "Found $DlCount files older than $([Math]::Abs($KillAge)) days`nSize to clean: $FilesToDeleteSizeFormatted`nStorage: $UsedSpace% full`nProceeding with cleanup"
    Show-Notification $MsgTitle $NotificationText
}
catch {
    Write-Log "Error calculating storage stats: $_"
}

# Delete Files
Write-Log "Starting file deletion..."
$DeletedCount = 0
$ErrorCount = 0
$DeletedSize = 0

foreach ($file in $KillList) {
    try {
        $fileSize = $file.Length
        Remove-Item -Path $file.FullName -Recurse -Force -ErrorAction Stop
        $DeletedCount++
        $DeletedSize += $fileSize
    }
    catch {
        Write-Log "Error deleting $($file.FullName): $_"
        $ErrorCount++
    }
}

# Get final folder size and calculate savings
$FinalFolderSize = (Get-ChildItem $TrimPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
$FinalFolderSizeFormatted = Format-FileSize -Size $FinalFolderSize
$SpaceSaved = $InitialFolderSize - $FinalFolderSize
$SpaceSavedFormatted = Format-FileSize -Size $SpaceSaved
$SpaceSavedPercentage = [math]::Round(($SpaceSaved / $InitialFolderSize) * 100, 1)

# Log completion details
Write-Log "Final Downloads folder size: $FinalFolderSizeFormatted"
Write-Log "Space saved: $SpaceSavedFormatted ($SpaceSavedPercentage% of initial size)"
Write-Log "Cleanup complete: $DeletedCount files deleted, $ErrorCount errors encountered"

# Notify Completion with size details
Show-Notification $MsgTitle "Cleanup complete:`n$DeletedCount files deleted`n$SpaceSavedFormatted space freed ($SpaceSavedPercentage%)"
Exit 0