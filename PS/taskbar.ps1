# Ensure running with administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as Administrator!"
    Exit
}

# Function to ensure registry path exists
function Ensure-RegistryPath {
    param (
        [string]$Path
    )
    if (!(Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
}

# Define registry paths
$paths = @{
    Advanced = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Search = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    Feeds = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"
    ExplorerPolicy = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
    WindowsExplorerPolicy = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
}

# Ensure all paths exist
foreach ($path in $paths.Values) {
    Ensure-RegistryPath -Path $path
}

# Configure taskbar settings
$settings = @{
    "$($paths.Advanced)" = @{
        "ShowTaskViewButton" = 0
        "TaskbarDa" = 0  # Widgets
        "TaskbarMn" = 0  # Edge
        "TaskbarApps" = 0  # Store
        "ShowCopilotButton" = 0
        "ShowAppIconInTaskbar" = 0
    }
    "$($paths.Search)" = @{
        "SearchboxTaskbarMode" = 1  # Icon only
    }
    "$($paths.Feeds)" = @{
        "EnableFeeds" = 0
    }
    "$($paths.ExplorerPolicy)" = @{
        "NoMSEdgePinningToTaskbar" = 1
    }
    "$($paths.WindowsExplorerPolicy)" = @{
        "ShowWindowsStoreAppsOnTaskbar" = 0
        "DisableWindowsStoreApplications" = 1
    }
}

# Apply all settings
foreach ($path in $settings.Keys) {
    foreach ($setting in $settings[$path].Keys) {
        try {
            Set-ItemProperty -Path $path -Name $setting -Value $settings[$path][$setting] -Type DWord -Force -ErrorAction Stop
            Write-Host "Successfully set $setting"
        }
        catch {
            Write-Host "Failed to set $setting : $_"
        }
    }
}

# Remove pinned apps from taskbar
$appKeys = @(
    "Microsoft.MicrosoftEdge*",
    "Microsoft.WindowsStore*",
    "Microsoft.Windows.Copilot*"
)

# Clean up explorer processes
try {
    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache*" -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe
    Write-Host "Explorer restarted successfully"
}
catch {
    Write-Host "Error restarting explorer: $_"
}

Write-Host "Taskbar customization complete. Please sign out and sign back in for all changes to take effect."