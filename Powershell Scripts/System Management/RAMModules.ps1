# Function to convert PowerShell objects to an HTML table with styling
function ConvertTo-ObjectToHtmlTable {
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[Object]]$Objects
    )
    # Initialize StringBuilder for better performance with string operations
    $sb = New-Object System.Text.StringBuilder
    
    # Add CSS styling for table appearance and responsiveness
    [void]$sb.Append(@"
    # ...existing CSS styling...
"@)

    # Create table header row based on object properties
    [void]$sb.Append('<table><thead><tr>')
    
    # Add column headers excluding the RowColour property
    $Objects[0].PSObject.Properties.Name |
    Where-Object { $_ -ne 'RowColour' } |
    ForEach-Object { [void]$sb.Append("<th>$_</th>") }

    # Process each object and create table rows
    [void]$sb.Append('</tr></thead><tbody>')
    
    # Check if output exceeds NinjaOne WYSIWYG field limit
    $OutputLength = $sb.ToString() | Measure-Object -Character -IgnoreWhiteSpace | Select-Object -ExpandProperty Characters
    if ($OutputLength -gt 200000) {
        Write-Warning ('Output appears to be over the NinjaOne WYSIWYG field limit of 200,000 characters. Actual length was: {0}' -f $OutputLength)
    }
    
    return $sb.ToString()
}

# Translate memory form factor codes to human-readable format
function Translate-FormFactor {
    param(
        [int]$FormFactor
    )
    switch ($FormFactor) {
        8 { return "DIMM" }      # Desktop memory
        12 { return "SODIMM" }   # Laptop memory
        default { return "Unknown" }
    }
}

# Translate SMBIOS memory types to DDR generation
function Translate-DDRType {
    param(
        [int]$SMBIOSMemoryType
    )
    switch ($SMBIOSMemoryType) {
        20 { return "DDR3" }
        21 { return "DDR3" }
        24 { return "DDR4" }
        25 { return "DDR4" }
        26 { return "DDR4" }
        30 { return "DDR5" }
        34 { return "DDR5" }
        default { return "Unknown" }
    }
}

# Retrieve detailed information about installed memory modules
function Get-MemoryInfo {
    [CmdletBinding()]
    param ()

    # Query WMI for physical memory information and format it
    Get-CimInstance -ClassName Win32_PhysicalMemory |
        ForEach-Object {
            [PSCustomObject]@{
                Tag           = $(try { ($_.Tag) -replace "`0", '' } catch { 'Not Found' })
                Slot          = $(try { ($_.DeviceLocator) -replace "`0", '' } catch { 'Not Found' })
                Size         = $(try { ($_.Capacity/1gb) -replace "`0", '' } catch { 'Not Found' }) + "GB"
                Manufacturer = $(try { ($_.Manufacturer) -replace "`0", '' } catch { 'Not Found' })
                PartCode     = $(try { ($_.PartNumber) -replace "`0", '' } catch { 'Not Found' })
                SerialNumber = $(try { $_.SerialNumber -replace "`0", '' } catch { 'Not Found' })
                FormFactor   = Get-WmiObject Win32_PhysicalMemory | Select-Object -ExpandProperty FormFactor | ForEach-Object { Translate-FormFactor -FormFactor $_ } | Get-Unique
                MemoryType   = Get-WmiObject Win32_PhysicalMemory | Select-Object -ExpandProperty SMBIOSMemoryType | ForEach-Object { Translate-DDRType -SMBIOSMemoryType $_ } | Get-Unique
                Speed        = $(try { $_.Speed -replace "`0", '' } catch { 'Not Found' })
                ClockSpeed   = $(try { $_.ConfiguredClockSpeed -replace "`0", '' } catch { 'Not Found' })
            }
        }
}

# Get information about memory slots (total, used, and free)
function Get-MemoryInfo2 {
    [CmdletBinding()]
    param ()
    $MemoryInfo2 = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Query physical memory array information
    Get-CimInstance -ClassName Win32_PhysicalMemoryArray |
        ForEach-Object {
            # Calculate slot usage
            $UsedSlots = (Get-CimInstance -ClassName win32_physicalmemory | Select-Object -Property BankLabel | Measure-Object).Count
            $TotalSlots = $_ | Select-Object -expandProperty MemoryDevices
            $FreeSlots = $TotalSlots - $UsedSlots

            # Create object with slot information and warning/success status
            $MemoryInfo2.Add(
                [PSCustomObject]@{
                    'Total Slots' = $TotalSlots
                    'Used Slots'  = $UsedSlots
                    'Free Slots'  = $FreeSlots
                    RowColour  = if ($FreeSlots -eq 0) { "warning" } else { "success" }
                }
            )
            return $MemoryInfo2
        }
}

# Main script execution
# Get memory module information and handle no memory case
$MemoryInfo = Get-MemoryInfo
if ($null -eq $MemoryInfo -or $MemoryInfo.Count -eq 0) {
    # Display error message if no memory detected
    $NoMemoryMessage = @"
    # ...existing HTML message...
"@
    $NoMemoryMessage | Ninja-Property-Set-Piped "installedMemoryUnable"
} else {
    # Convert memory information to HTML table
    $Output = ConvertTo-ObjectToHTMLTable -Objects $MemoryInfo
    $Output | Ninja-Property-Set-Piped "installedMemoryUnable"
}

# Get and display memory slot information
$MemoryInfo2 = Get-MemoryInfo2
if ($MemoryInfo2 -isnot [System.Collections.Generic.List[PSCustomObject]]) {
    $MemoryInfo2 = [System.Collections.Generic.List[PSCustomObject]]$MemoryInfo2
}
$Output2 = ConvertTo-ObjectToHTMLTable -Objects $MemoryInfo2
$Output2 | Ninja-Property-Set-Piped "physicalMemorySlots"