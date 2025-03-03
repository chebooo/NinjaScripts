#!/bin/bash

# Configuration
DAYS_OLD=14  # 2 weeks
# Use a generic path that will work for any user
SCREENSHOTS_DIR="/Users/$(stat -f "%Su" /dev/console)/Desktop/Screenshots"


# Enable debug output
DEBUG=true

# Debug function
debug_echo() {
    if [ "$DEBUG" = true ]; then
        echo ">>> $1"
    fi
}

debug_echo "=== Screenshot Cleanup Script Started ==="
debug_echo "Looking in directory: $SCREENSHOTS_DIR"
debug_echo "Searching for screenshots older than $DAYS_OLD days"

# Check if Screenshots directory exists
if [ ! -d "$SCREENSHOTS_DIR" ]; then
    echo "ERROR: Screenshots directory not found at $SCREENSHOTS_DIR"
    exit 1
fi

# Function to convert bytes to human readable format
format_size() {
    local bytes=$1
    if [ $bytes -gt 1073741824 ]; then # 1GB
        echo "$(bc <<< "scale=2; $bytes/1073741824") GB"
    elif [ $bytes -gt 1048576 ]; then # 1MB
        echo "$(bc <<< "scale=2; $bytes/1048576") MB"
    elif [ $bytes -gt 1024 ]; then # 1KB
        echo "$(bc <<< "scale=2; $bytes/1024") KB"
    else
        echo "$bytes bytes"
    fi
}

# Function to show native notification
show_notification() {
    local message="$1"
    local logged_in_user=$(stat -f "%Su" /dev/console)
    local user_id=$(id -u "$logged_in_user")

    # Just use the most reliable method we found
    debug_echo "Sending notification..."
    launchctl asuser "$user_id" /usr/bin/osascript -e "display notification \"$message\" with title \"Screenshot Cleanup\""
}

# Function to check if a file is locked/in use
is_file_in_use() {
    local file="$1"
    lsof "$file" >/dev/null 2>&1
    return $?
}

debug_echo "Starting screenshot search..."

# Create temporary files to store the count and total size
temp_count_file=$(mktemp)
temp_size_file=$(mktemp)
echo "0" > "$temp_count_file"
echo "0" > "$temp_size_file"

# Calculate the cutoff date in seconds since epoch (14 days ago)
cutoff_date=$(date -v-${DAYS_OLD}d +%s)

# Find and process screenshot files
find "$SCREENSHOTS_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "Screen Shot*.png" -o -name "Screenshot*.png" \) -print0 | while IFS= read -r -d $'\0' item; do
    # Get file creation time in seconds since epoch
    file_date=$(stat -f %B "$item")
    
    # Compare with cutoff date
    if [ $file_date -lt $cutoff_date ]; then
        debug_echo "Found old screenshot: $(basename "$item")"
        
        # Skip if file is in use
        if is_file_in_use "$item"; then
            debug_echo "SKIPPED: File is in use: $(basename "$item")"
            continue
        fi
        
        # Get file size before deletion
        file_size=$(stat -f %z "$item")
        
        # Perform actual deletion
        debug_echo "Removing Screenshot: $(basename "$item") ($(format_size $file_size))"
        rm -f "$item" 2>/dev/null
        
        # Update count and total size
        count=$(cat "$temp_count_file")
        total_size=$(cat "$temp_size_file")
        echo $((count + 1)) > "$temp_count_file"
        echo $((total_size + file_size)) > "$temp_size_file"
    else
        debug_echo "Skipping recent file: $(basename "$item")"
    fi
done