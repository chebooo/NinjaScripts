# Set the threshold for battery health alerts (in percentage)
$AlertPercent = 70

# Generate a battery report in XML format using Windows power configuration tool
& powercfg /batteryreport /XML /OUTPUT "batteryreport.xml"

# Wait for the report to be generated
Start-Sleep 1

# Load and parse the XML report
[xml]$Report = Get-Content "batteryreport.xml"

# Extract relevant battery information from the report
# Create custom objects with battery specifications
$BatteryStatus = $Report.BatteryReport.Batteries |
ForEach-Object {
    [PSCustomObject]@{
        DesignCapacity = $_.Battery.DesignCapacity      # Original capacity when new
        FullChargeCapacity = $_.Battery.FullChargeCapacity  # Current maximum capacity
        CycleCount = $_.Battery.CycleCount             # Number of charge cycles
        Id = $_.Battery.id                            # Battery identifier
    }
}

# Check if any batteries were detected
if (!$BatteryStatus) {
    Write-Host "This device does not have batteries, or we could not find the status of the batteries."
}

# Check each battery's health against the alert threshold
foreach ($Battery in $BatteryStatus) {
    # Calculate current capacity as percentage of original design capacity
    if ([int64]$Battery.FullChargeCapacity * 100 / [int64]$Battery.DesignCapacity -lt $AlertPercent) {
        Write-host "The battery health is less than expect. The battery was designed for $($battery.DesignCapacity) but the maximum charge is $($Battery.FullChargeCapacity). The battery info is $($Battery.id)"
    }
}