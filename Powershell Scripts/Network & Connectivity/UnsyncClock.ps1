# Windows Clock Synchronization Script
# Ensure the script is running with administrative privileges
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Host "This script requires administrative privileges. Please run as an administrator." -ForegroundColor Red
    Exit 1
}

# Define the desired time zone ID for the United Kingdom
$desiredTimeZone = "GMT Standard Time"

# Get the current time zone
$currentTimeZone = (Get-TimeZone).Id

# Check if the current time zone matches the desired time zone
If ($currentTimeZone -ne $desiredTimeZone)
{
    Try
    {
        # Set the desired time zone
        Set-TimeZone -Id $desiredTimeZone
        Write-Host "Time zone set to $desiredTimeZone." -ForegroundColor Green
    }
    Catch
    {
        Write-Host "Failed to set time zone. Error: $_" -ForegroundColor Red
        # Continue execution even if time zone setting fails
    }
}
Else
{
    Write-Host "Time zone is already set to $desiredTimeZone." -ForegroundColor Green
}

# Enable Windows Time service to start automatically
Try {
    Set-Service -Name w32time -StartupType Automatic
    Write-Host "Windows Time service set to start automatically." -ForegroundColor Green
} Catch {
    Write-Host "Failed to set Windows Time service to automatic startup. Error: $_" -ForegroundColor Red
}

# Set the time service to use NTP (restore from NoSync if it was changed)
Try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "Type" -Value "NTP" -ErrorAction Stop
    Write-Host "Windows Time service configured to use NTP." -ForegroundColor Green
} Catch {
    Write-Host "Failed to configure time service type. Error: $_" -ForegroundColor Red
}

# Ensure the Windows Time service is running
Try
{
    $service = Get-Service -Name w32time -ErrorAction Stop
    If ($service.Status -ne 'Running')
    {
        Start-Service -Name w32time
        Write-Host "Windows Time service started." -ForegroundColor Green
    }
    Else
    {
        Write-Host "Windows Time service is already running." -ForegroundColor Green
    }
}
Catch
{
    Write-Host "Failed to check or start Windows Time service. Error: $_" -ForegroundColor Red
    Exit 1
}

# Configure time servers
Try {
    w32tm /config /syncfromflags:manual /manualpeerlist:"time.windows.com,0.pool.ntp.org,1.pool.ntp.org,2.pool.ntp.org" /update
    Write-Host "Time servers configured successfully." -ForegroundColor Green
} Catch {
    $ErrorMessage = $_.Exception.Message
    Write-Host "Failed to configure time servers. Error: $ErrorMessage" -ForegroundColor Red
}

# Restart the Windows Time service to apply changes
Try {
    Restart-Service w32time -Force
    Write-Host "Windows Time service restarted." -ForegroundColor Green
    Start-Sleep -Seconds 2  # Give the service a moment to initialize
} Catch {
    Write-Host "Failed to restart Windows Time service. Error: $_" -ForegroundColor Red
}

# Synchronize the system time
Try
{
    # Use cmd.exe to run w32tm and capture its output since it's not a native PowerShell command
    $result = cmd.exe /c "w32tm /resync /force 2>&1"
    
    # Check if the command executed successfully
    if ($result -match "The command completed successfully") {
        Write-Host "System time synchronized successfully." -ForegroundColor Green
    } else {
        Write-Host "Time synchronization completed with message: $result" -ForegroundColor Yellow
    }
}
Catch
{
    Write-Host "Time synchronization failed. Error: $_" -ForegroundColor Red
}

# Display the current time for verification
Write-Host "Current system time: $(Get-Date)" -ForegroundColor Cyan