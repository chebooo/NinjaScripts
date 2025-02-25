Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Define a hidden save directory inside AppData
$saveDir = [System.IO.Path]::Combine($env:APPDATA, "Microsoft", "Windows", "SystemFiles")

# Ensure the directory exists
if (!(Test-Path -Path $saveDir)) {
    New-Item -ItemType Directory -Path $saveDir -Force | Out-Null
}

# Initialize an empty list to store each screen's bitmap
$bitmaps = @()
$totalWidth = 0
$maxHeight = 0

# Capture each screen and store the bitmaps in the list
[System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
    $screen = $_
    $bounds = $screen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
    
    # Add the bitmap to the list
    $bitmaps += $bitmap

    # Update total width and max height
    $totalWidth += $bounds.Width
    if ($bounds.Height -gt $maxHeight) {
        $maxHeight = $bounds.Height
    }

    # Clean up the graphics object
    $graphics.Dispose()
}

# Create a new bitmap with the total width of all screens combined and the max height
$finalImage = New-Object System.Drawing.Bitmap $totalWidth, $maxHeight
$finalGraphics = [System.Drawing.Graphics]::FromImage($finalImage)

# Draw each screen's bitmap onto the final image
$xOffset = 0
foreach ($bitmap in $bitmaps) {
    $finalGraphics.DrawImage($bitmap, $xOffset, 0)
    $xOffset += $bitmap.Width
    $bitmap.Dispose()
}

# Define the final output file path
$outputPath = "$saveDir\Combined_Screenshot_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"
$finalImage.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Clean up final graphics and bitmap objects
$finalGraphics.Dispose()
$finalImage.Dispose()

# Display the saved location in the terminal
Write-Output "`nScreenshot saved successfully!"
Write-Output "File location: $outputPath"
