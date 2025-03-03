# Windows Clock Unsynchronization Script
# Ensure the script is running with administrative privileges
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Host "This script requires administrative privileges. Please run as an administrator." -ForegroundColor Red
    Exit 1
}

# Display current time
Write-Host "Current system time before changes: $(Get-Date)" -ForegroundColor Cyan

# Stop the Windows Time service
Try {
    Stop-Service -Name w32time -Force
    Write-Host "Windows Time service stopped." -ForegroundColor Green
} Catch {
    Write-Host "Failed to stop Windows Time service. Error: $_" -ForegroundColor Red
}

# Set the time service to NoSync mode
Try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "Type" -Value "NoSync" -ErrorAction Stop
    Write-Host "Windows Time service configured to NoSync mode." -ForegroundColor Green
} Catch {
    Write-Host "Failed to configure time service type. Error: $_" -ForegroundColor Red
}

# Disable automatic start of Windows Time service
Try {
    Set-Service -Name w32time -StartupType Disabled
    Write-Host "Windows Time service set to disabled startup type." -ForegroundColor Green
} Catch {
    Write-Host "Failed to set Windows Time service to disabled. Error: $_" -ForegroundColor Red
}

# Set system time to a different value (1 hour behind)
Try {
    $newTime = (Get-Date).AddHours(-1)
    Set-Date -Date $newTime
    Write-Host "System clock set to 1 hour behind." -ForegroundColor Green
} Catch {
    Write-Host "Failed to change system time. Error: $_" -ForegroundColor Red
}

# Display the new time for verification
Write-Host "New system time: $(Get-Date)" -ForegroundColor Cyan

Write-Host "The system clock has been successfully unsynced. Time synchronization is now disabled." -ForegroundColor Yellow
Write-Host "You can now test your SynchroniseTime.ps1 script." -ForegroundColor Yellow