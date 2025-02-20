# ------------------------
# Downloads Folder Cleanup Script with BurntToast Notifications
# ------------------------

# Check if the script is being run as the SYSTEM user.
# SYSTEM accounts typically don't have a standard Downloads folder, so we exit early.
If( ([System.Security.Principal.WindowsIdentity]::GetCurrent()).Name -eq 'NT AUTHORITY\SYSTEM') {
    Write-Host "Downloads folder cleanup of local SYSTEM user is not supported, exiting."
    Exit 1
}

# ------------------------
# Ensure BurntToast Module is Installed
# ------------------------

# BurntToast is a PowerShell module used for sending Windows Toast Notifications.
# Check if the BurntToast module is installed. If not, install it.
If (-not (Get-Module -ListAvailable -Name BurntToast)) {
    Install-Module -Name BurntToast -Force -Scope CurrentUser
}

# Import the BurntToast module to use its notification functions.
Import-Module BurntToast

# ------------------------
# Define Constants and Paths
# ------------------------

# Number of days after which files will be deleted (-60 means files older than 60 days)
$KillAge = -60  

# Percentage of disk usage at which cleanup notifications sound more urgent
$ShameThreshold = 90  

# Define the path to the user's Downloads folder
$TrimPath = "$($env:USERPROFILE)\Downloads"

# Title to be used in toast notifications
$MsgTitle = "Cleanup of Downloads Folder"

# Path to a custom image for toast notifications (modify as needed)
$CustomImage = "C:\Users\sebastian.astalos_hi\Desktop\PS\DownloadsCleanup\Screenshot 2025-02-20 120704.png"

# ------------------------
# Identify Files to be Deleted
# ------------------------

# Retrieve a list of files in the Downloads folder that were last modified more than 60 days ago.
$KillList = Get-ChildItem $TrimPath -Recurse | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays($KillAge) }

# ------------------------
# Notify If No Files Are Found
# ------------------------

# If there are no files matching the criteria, send a notification and exit the script.
If ($KillList -eq $null) {
    New-BurntToastNotification -Text "$MsgTitle", "No files older than $([Math]::Abs($KillAge)) days to clean up" -AppLogo $CustomImage
    Exit 0
}

# ------------------------
# Gather Storage Statistics
# ------------------------

# Retrieve storage details for the system drive (usually C:)
$OSVol = Get-WMIObject Win32_Volume | Where-Object { $_.DriveLetter -eq ($env:SystemDrive) }

# Calculate disk usage percentage (rounded to 1 decimal place)
$UsedSpace = [math]::round(($OSVol.Capacity - $OSVol.FreeSpace) / $OSVol.Capacity * 100, 1)

# Count the number of files to be deleted
$DlCount = ($KillList | Measure-Object Length).Count

# Calculate the total size of the files to be deleted (in GB, rounded to 2 decimal places)
$DlSize = [math]::round(($KillList | Measure-Object Length -Sum).Sum / 1Gb, 2)

# ------------------------
# Notify User Before Cleanup Begins
# ------------------------

# Construct a properly formatted notification message with cleanup details.
$NotificationText = "Found $DlCount items older than $([Math]::Abs($KillAge)) days`nTotal size: $DlSize GB`nStorage is $UsedSpace% full`nProceeding with cleanup"

# Create an "OK" button for the notification.
$action = New-BTButton -Content "OK" -Dismiss

# Send a Windows Toast Notification informing the user about the cleanup.
New-BurntToastNotification -Text "$MsgTitle", $NotificationText -AppLogo $CustomImage -Button $action

# ------------------------
# Perform File Deletion
# ------------------------

# Delete the identified files quietly, without prompting for confirmation.
$KillList | Remove-Item -Recurse -ErrorAction SilentlyContinue -Confirm:$False

# ------------------------
# Notify User of Completion
# ------------------------

# Create a message for the cleanup completion notification.
$CompletionText = "Folder cleanup complete`nClick OK to dismiss"

# Send a final notification to inform the user that the cleanup has finished.
New-BurntToastNotification -Text "$MsgTitle", $CompletionText -AppLogo $CustomImage -Button $action

# Exit script successfully.
Exit 0
