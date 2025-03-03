# Script to populate Downloads folder with test files of various sizes and dates
# This will create approximately 2GB of test data

# Target location
$DownloadsPath = "$($env:USERPROFILE)\Downloads\TestFiles"

# Create the test directory if it doesn't exist
if (-not (Test-Path -Path $DownloadsPath)) {
    New-Item -Path $DownloadsPath -ItemType Directory -Force | Out-Null
    Write-Host "Created test directory: $DownloadsPath"
}

# Function to create a file of specified size with random content
function Create-TestFile {
    param (
        [string]$FilePath,
        [int]$SizeMB,
        [DateTime]$LastWriteTime
    )
    
    try {
        # Create a file stream
        $fileStream = [System.IO.File]::Create($FilePath)
        
        # Create a buffer with random bytes (1MB at a time to save memory)
        $bufferSize = 1MB
        $buffer = New-Object byte[] $bufferSize
        $random = New-Object System.Random
        
        # Write the buffer to the file multiple times to reach desired size
        $remainingMB = $SizeMB
        while ($remainingMB -gt 0) {
            # For the last iteration, adjust buffer size if needed
            if ($remainingMB -lt 1) {
                $bufferSize = [int]($remainingMB * 1MB)
                $buffer = New-Object byte[] $bufferSize
            }
            
            $random.NextBytes($buffer)
            $fileStream.Write($buffer, 0, $buffer.Length)
            $remainingMB--
        }
        
        # Close the file
        $fileStream.Close()
        
        # Set the last write time
        Set-ItemProperty -Path $FilePath -Name LastWriteTime -Value $LastWriteTime
        
        return $true
    }
    catch {
        Write-Warning "Failed to create file $FilePath : $_"
        return $false
    }
}

# Create an array of file definitions (name, size in MB, age in days)
$fileDefinitions = @(
    # Old files (should be deleted by cleanup script)
    @{ Name = "OldLargeFile.dat"; Size = 300; AgeDays = 90 },
    @{ Name = "OldMediumFile.dat"; Size = 150; AgeDays = 80 },
    @{ Name = "OldArchive.zip"; Size = 200; AgeDays = 75 },
    @{ Name = "OldDocument.docx"; Size = 50; AgeDays = 70 },
    @{ Name = "OldBackup.bak"; Size = 250; AgeDays = 65 },
    
    # Recent files (should be kept by cleanup script)
    @{ Name = "RecentLargeFile.dat"; Size = 300; AgeDays = 30 },
    @{ Name = "RecentMediumFile.dat"; Size = 150; AgeDays = 25 },
    @{ Name = "RecentArchive.zip"; Size = 200; AgeDays = 20 },
    @{ Name = "RecentDocument.docx"; Size = 50; AgeDays = 15 },
    @{ Name = "RecentBackup.bak"; Size = 250; AgeDays = 10 },
    
    # Very recent files (should definitely be kept)
    @{ Name = "VeryRecentLargeFile.dat"; Size = 100; AgeDays = 5 },
    @{ Name = "VeryRecentDocument.docx"; Size = 50; AgeDays = 2 }
)

# Create a folder structure with some files in subfolders
$subfolders = @(
    "OldFolder",
    "RecentFolder",
    "MixedFolder"
)

# Create the subfolders
foreach ($folder in $subfolders) {
    $folderPath = Join-Path -Path $DownloadsPath -ChildPath $folder
    if (-not (Test-Path -Path $folderPath)) {
        New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
        Write-Host "Created subfolder: $folderPath"
    }
}

# Create the test files
$totalSizeMB = 0
$totalFiles = 0
$successFiles = 0

# First, create files in the root test folder
foreach ($file in $fileDefinitions) {
    $filePath = Join-Path -Path $DownloadsPath -ChildPath $file.Name
    $date = (Get-Date).AddDays(-$file.AgeDays)
    
    Write-Host "Creating file: $($file.Name) - Size: $($file.Size) MB - Age: $($file.AgeDays) days"
    
    $success = Create-TestFile -FilePath $filePath -SizeMB $file.Size -LastWriteTime $date
    
    if ($success) {
        $totalSizeMB += $file.Size
        $successFiles++
    }
    
    $totalFiles++
}

# Now create some additional files in the subfolders
$subfoldersFileDefinitions = @(
    # OldFolder - files older than 60 days
    @{ Folder = "OldFolder"; Name = "OldSubfolderFile1.dat"; Size = 100; AgeDays = 85 },
    @{ Folder = "OldFolder"; Name = "OldSubfolderFile2.dat"; Size = 50; AgeDays = 75 },
    
    # RecentFolder - files newer than 60 days
    @{ Folder = "RecentFolder"; Name = "RecentSubfolderFile1.dat"; Size = 100; AgeDays = 45 },
    @{ Folder = "RecentFolder"; Name = "RecentSubfolderFile2.dat"; Size = 50; AgeDays = 35 },
    
    # MixedFolder - mix of old and new files
    @{ Folder = "MixedFolder"; Name = "MixedOldFile.dat"; Size = 100; AgeDays = 80 },
    @{ Folder = "MixedFolder"; Name = "MixedRecentFile.dat"; Size = 50; AgeDays = 30 }
)

foreach ($file in $subfoldersFileDefinitions) {
    $folderPath = Join-Path -Path $DownloadsPath -ChildPath $file.Folder
    $filePath = Join-Path -Path $folderPath -ChildPath $file.Name
    $date = (Get-Date).AddDays(-$file.AgeDays)
    
    Write-Host "Creating file: $($file.Folder)\$($file.Name) - Size: $($file.Size) MB - Age: $($file.AgeDays) days"
    
    $success = Create-TestFile -FilePath $filePath -SizeMB $file.Size -LastWriteTime $date
    
    if ($success) {
        $totalSizeMB += $file.Size
        $successFiles++
    }
    
    $totalFiles++
}

# Report results
Write-Host "`nTest files creation complete:"
Write-Host "------------------------------"
Write-Host "Total files attempted: $totalFiles"
Write-Host "Successfully created: $successFiles"
Write-Host "Total size: $totalSizeMB MB (approximately $([math]::Round($totalSizeMB/1024, 2)) GB)"
Write-Host "Location: $DownloadsPath"
Write-Host "`nYou can now run your cleanup script to test removal of files older than 60 days"