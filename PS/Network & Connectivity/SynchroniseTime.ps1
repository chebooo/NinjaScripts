# Sets time-zone to the united kingdom and synchronises the time 

# Ensure the script is running with administrative privileges
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Host "This script requires administrative privileges. Please run as an administrator."
    Exit
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
        Write-Host "Time zone set to $desiredTimeZone."
    }
    Catch
    {
        Write-Host "Failed to set time zone. Error: $_"
        Exit
    }
}
Else
{
    Write-Host "Time zone is already set to $desiredTimeZone."
}

# Ensure the Windows Time service is running
Try
{
    $service = Get-Service -Name w32time -ErrorAction Stop
    If ($service.Status -ne 'Running')
    {
        Start-Service -Name w32time
        Write-Host "Windows Time service started."
    }
    Else
    {
        Write-Host "Windows Time service is already running."
    }
}
Catch
{
    Write-Host "Failed to start Windows Time service. Error: $_"
    Exit
}

# Synchronize the system time
Try
{
    w32tm /resync /force
    Write-Host "System time synchronized successfully."
}
Catch
{
    Write-Host "Time synchronization failed. Error: $_"
}

