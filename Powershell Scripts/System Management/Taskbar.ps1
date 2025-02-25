# Define array of applications to be unpinned from taskbar
# These are common Windows 11 default pinned applications
$appnames = "Microsoft Edge", "Microsoft Store", "Microsoft Teams (personal)", "Chat", "Copilot (preview)", "Copilot", "Outlook (new)"

# Process each application in the array
foreach ($appname in $appnames) {
    try {
        # Access the Windows Shell to manage taskbar items
        # CLSID 4234d49b-0245-4df3-b780-3893943456e1 represents the taskbar location
        # Find the specific application by name and execute the 'Unpin from taskbar' verb
        ((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | 
            ?{$_.Name -eq $appname}).Verbs() | 
            ?{$_.Name.replace('&','') -match 'Unpin from taskbar'} | 
            %{$_.DoIt(); $exec = $true}
    }
    catch {
        # Log any errors that occur during the unpinning process
        Write-Host "Error:"$_.Exception.Message
    }
}