# Downloads Folder Cleanup Script with BurntToast Notifications

# Exit if running as SYSTEM (no standard Downloads folder)
If( ([System.Security.Principal.WindowsIdentity]::GetCurrent()).Name -eq 'NT AUTHORITY\SYSTEM') {
    Write-Host "Exiting: SYSTEM user not supported."
    Exit 1
}

# Ensure BurntToast Module is Installed
If (-not (Get-Module -ListAvailable -Name BurntToast)) {
    Install-Module -Name BurntToast -Force -Scope CurrentUser
}
Import-Module BurntToast

# Configurable Settings
$KillAge = -60  # Delete files older than 60 days
$ShameThreshold = 90  # Disk usage warning threshold
$TrimPath = "$($env:USERPROFILE)\Downloads"
$MsgTitle = "Downloads Cleanup"
$CustomImage = "C:\Users\sebastian.astalos_hi\Desktop\Powershell Scripts\DownloadsCleanup\Screenshot 2025-02-20 120704.png"

# Identify Files to Delete
$KillList = Get-ChildItem $TrimPath -Recurse | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays($KillAge) }

# Notify if No Files Found
If (-not $KillList) {
    New-BurntToastNotification -Text "$MsgTitle", "No files older than $([Math]::Abs($KillAge)) days" -AppLogo $CustomImage
    Exit 0
}

# Gather Storage Stats
$OSVol = Get-WMIObject Win32_Volume | Where-Object { $_.DriveLetter -eq ($env:SystemDrive) }
$UsedSpace = [math]::round(($OSVol.Capacity - $OSVol.FreeSpace) / $OSVol.Capacity * 100, 1)
$DlCount = $KillList.Count
$DlSize = [math]::round(($KillList | Measure-Object Length -Sum).Sum / 1Gb, 2)

# Notify User Before Cleanup
$NotificationText = "Found $DlCount files older than $([Math]::Abs($KillAge)) days`nTotal size: $DlSize GB`nStorage: $UsedSpace% full`nProceeding..."
$action = New-BTButton -Content "OK" -Dismiss
New-BurntToastNotification -Text "$MsgTitle", $NotificationText -AppLogo $CustomImage -Button $action

# Delete Files
$KillList | Remove-Item -Recurse -ErrorAction SilentlyContinue -Confirm:$False

# Notify Completion
New-BurntToastNotification -Text "$MsgTitle", "Cleanup complete`nClick OK to dismiss" -AppLogo $CustomImage -Button $action
Exit 0
