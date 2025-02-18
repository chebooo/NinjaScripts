$Monitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID
$ParsedMonitors = @()

ForEach ($Monitor in $Monitors) {
    $Manufacturer = if ($Monitor.ManufacturerName) {
        [System.Text.Encoding]::ASCII.GetString($Monitor.ManufacturerName).TrimEnd([char]0)
    } else { "Unknown Manufacturer" }
    
    $Name = if ($Monitor.UserFriendlyName) {
        [System.Text.Encoding]::ASCII.GetString($Monitor.UserFriendlyName).TrimEnd([char]0)
    } else { "Unknown Model" }
    
    $Serial = if ($Monitor.SerialNumberID) {
        [System.Text.Encoding]::ASCII.GetString($Monitor.SerialNumberID).TrimEnd([char]0)
    } else { "Unknown Serial" }
    
    $ParsedMonitors += "Monitor: $Manufacturer | Model: $Name | Serial: $Serial`n"
}

Ninja-Property-Set 'monitors' ($ParsedMonitors -join "")
