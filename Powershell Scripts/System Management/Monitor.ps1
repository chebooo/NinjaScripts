# Query WMI for monitor information from the root\wmi namespace
$Monitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID

# Initialize an array to store formatted monitor information
$ParsedMonitors = @()

# Process each monitor found
ForEach ($Monitor in $Monitors) {
    # Extract and decode manufacturer name from byte array, fallback to "Unknown Manufacturer" if not available
    $Manufacturer = if ($Monitor.ManufacturerName) {
        [System.Text.Encoding]::ASCII.GetString($Monitor.ManufacturerName).TrimEnd([char]0)
    } else { "Unknown Manufacturer" }
    
    # Extract and decode model name from byte array, fallback to "Unknown Model" if not available
    $Name = if ($Monitor.UserFriendlyName) {
        [System.Text.Encoding]::ASCII.GetString($Monitor.UserFriendlyName).TrimEnd([char]0)
    } else { "Unknown Model" }
    
    # Extract and decode serial number from byte array, fallback to "Unknown Serial" if not available
    $Serial = if ($Monitor.SerialNumberID) {
        [System.Text.Encoding]::ASCII.GetString($Monitor.SerialNumberID).TrimEnd([char]0)
    } else { "Unknown Serial" }
    
    # Format monitor information and add to array with newline character
    $ParsedMonitors += "Monitor: $Manufacturer | Model: $Name | Serial: $Serial`n"
}

# Set the 'monitors' property in NinjaOne with all monitor information joined together
Ninja-Property-Set 'monitors' ($ParsedMonitors -join "")