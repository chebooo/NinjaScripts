# Get WiFi SSID PowerShell Script for NinjaOne
# Compatible with older systems and various network adapter configurations

try {
    $output = @{
        'SSID' = ''
        'InterfaceName' = ''
        'ConnectionStatus' = ''
        'TimeStamp' = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    # Method 1: Try using netsh with additional error handling
    try {
        $netshOutput = netsh wlan show interfaces
        
        # Only process if netshOutput actually contains data
        if ($netshOutput -and $netshOutput.Count -gt 0) {
            $ssidLine = $netshOutput | Where-Object { $_ -match 'SSID\s+:' } | Select-Object -First 1
            if ($ssidLine -match 'SSID\s+:\s+(.+)') {
                $output.SSID = $matches[1].Trim()
                
                $nameLine = $netshOutput | Where-Object { $_ -match 'Name\s+:' } | Select-Object -First 1
                if ($nameLine -match 'Name\s+:\s+(.+)') {
                    $output.InterfaceName = $matches[1].Trim()
                }
                
                $stateLine = $netshOutput | Where-Object { $_ -match 'State\s+:' } | Select-Object -First 1
                if ($stateLine -match 'State\s+:\s+(.+)') {
                    $output.ConnectionStatus = $matches[1].Trim()
                }
            }
        }
    } catch {
        # Silently continue to next method if this fails
    }

    # Method 2: Try Network Adapter method if first method failed
    if ([string]::IsNullOrEmpty($output.SSID)) {
        try {
            # Check for any wireless network adapters
            $wifiAdapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | 
                Where-Object { $_.PhysicalMediaType -eq 'Native 802.11' -or 
                             $_.Name -like '*Wireless*' -or 
                             $_.Name -like '*Wi-Fi*' -or 
                             $_.InterfaceDescription -like '*Wireless*' -or 
                             $_.InterfaceDescription -like '*Wi-Fi*' })

            if ($wifiAdapters.Count -gt 0) {
                foreach ($adapter in $wifiAdapters) {
                    $profile = Get-NetConnectionProfile -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue
                    if ($profile) {
                        $output.SSID = $profile.Name
                        $output.InterfaceName = $adapter.Name
                        $output.ConnectionStatus = $profile.NetworkCategory.ToString()
                        break
                    }
                }
            }
        } catch {
            # Silently continue to next method if this fails
        }
    }

    # Method 3: Legacy fallback using WMI
    if ([string]::IsNullOrEmpty($output.SSID)) {
        try {
            $wmiAdapter = Get-WmiObject -Class Win32_NetworkAdapter -Filter "NetConnectionID like '%Wi-Fi%' OR NetConnectionID like '%Wireless%'" -ErrorAction SilentlyContinue |
                Where-Object { $_.NetEnabled -eq $true } |
                Select-Object -First 1

            if ($wmiAdapter) {
                $wmiConfig = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "InterfaceIndex = '$($wmiAdapter.InterfaceIndex)'" -ErrorAction SilentlyContinue
                if ($wmiConfig -and $wmiConfig.DHCPEnabled) {
                    $output.SSID = $wmiConfig.DNSDomain
                    $output.InterfaceName = $wmiAdapter.NetConnectionID
                    $output.ConnectionStatus = "Connected"
                }
            }
        } catch {
            # Silently continue if this fails
        }
    }

    # Final output
    if (![string]::IsNullOrEmpty($output.SSID)) {
        $jsonResult = $output | ConvertTo-Json
        Write-Output $jsonResult
    } else {
        # Create a diagnostic output
        $diagnostics = @{
            'Error' = 'No WiFi connection found'
            'AvailableAdapters' = @(Get-NetAdapter -ErrorAction SilentlyContinue | 
                Where-Object { $_.PhysicalMediaType -eq 'Native 802.11' -or 
                             $_.Name -like '*Wireless*' -or 
                             $_.Name -like '*Wi-Fi*' } | 
                Select-Object Name, Status, PhysicalMediaType | ForEach-Object { 
                    @{
                        'Name' = $_.Name
                        'Status' = $_.Status.ToString()
                        'Type' = $_.PhysicalMediaType
                    }
                })
            'TimeStamp' = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        Write-Output ($diagnostics | ConvertTo-Json)
    }
} catch {
    $errorDetail = @{
        'Error' = "Script execution failed: $($_.Exception.Message)"
        'TimeStamp' = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    Write-Output ($errorDetail | ConvertTo-Json)
}