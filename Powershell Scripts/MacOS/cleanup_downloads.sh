#!/bin/bash

# Configuration
DAYS_OLD=14  # Changed to 14 days (2 weeks)
DOWNLOADS_DIR="$HOME/Downloads"

# Enable debug output
DEBUG=true

# Debug function
debug_echo() {
    if [ "$DEBUG" = true ]; then
        echo ">>> $1"
    fi
}

debug_echo "=== Download Cleanup Script Started ==="
debug_echo "Looking in directory: $DOWNLOADS_DIR"
debug_echo "Searching for files older than $DAYS_OLD days"

# Check if Downloads directory exists
if [ ! -d "$DOWNLOADS_DIR" ]; then
    echo "ERROR: Downloads directory not found at $DOWNLOADS_DIR"
    exit 1
fi

# Function to check if a file is locked/in use
is_file_in_use() {
    local file="$1"
    lsof "$file" >/dev/null 2>&1
    return $?
}

# Function to safely remove items
safe_remove() {
    local item="$1"
    
    # Skip .app directories and their contents
    if [[ "$item" == *.app* ]]; then
        return
    fi
    
    # Get file age in days
    local age=$(( ( $(date +%s) - $(stat -f %m "$item") ) / 86400 ))
    
    # Only process top-level items
    if [ "$(dirname "$item")" = "$DOWNLOADS_DIR" ]; then
        debug_echo "Found item: $(basename "$item") (${age} days old)"
        
        # Skip if file is in use
        if is_file_in_use "$item"; then
            debug_echo "SKIPPED: File is in use: $(basename "$item")"
            return
        fi
        
        # Perform actual deletion
        if [ -d "$item" ]; then
            debug_echo "Removing Directory: $(basename "$item")"
            rm -rf "$item" 2>/dev/null
        else
            debug_echo "Removing File: $(basename "$item")"
            rm -f "$item" 2>/dev/null
        fi
    fi
}

debug_echo "Starting file search..."

# Find and remove old files
find "$DOWNLOADS_DIR" -mindepth 1 -mtime +$DAYS_OLD -print0 | while IFS= read -r -d $'\0' item; do
    safe_remove "$item"
done

debug_echo "=== Script Completed ==="
exit 0

