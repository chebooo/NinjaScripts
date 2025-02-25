Get-ItemProperty -Path "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" ,
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
Where-Object { $_.DisplayName -ne $null -and $_.InstallLocation } | 
Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallLocation, QuietUninstallString, UninstallString,
@{
    Name = "Architecture"
    Expression = { 
        if ($_.InstallLocation -like "*Program Files (x86)*") { 
            "32-bit" 
        } elseif ($_.InstallLocation) { 
            "64-bit" 
        } elseif ($_.PSPath -like "*WOW6432Node*") { "32-bit" } else { "64-bit" }
}},
@{
    Name = "InstallContext"  # New column for installing user
    Expression = { 
        if ($_.InstallLocation -like "*Program Files*" -or "*Program Files (x86)*") {
            "System"
        } else {
           "" 
        }}} | Sort-Object DisplayName, @{Expression = { [version]$_.DisplayVersion }; Descending = $true } | Format-Table -AutoSize