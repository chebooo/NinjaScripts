#!/bin/bash

# Configuration
SCREENSHOTS_DIR="/Users/sebastian.astalos/Desktop/Screenshots_Test"

# Create Screenshots directory if it doesn't exist
mkdir -p "$SCREENSHOTS_DIR"

# Debug output
echo "Creating test screenshots in: $SCREENSHOTS_DIR"

# Function to create a file with a specific date and size
create_dated_file() {
    local filename="$1"
    local days_ago="$2"
    local size="$3"  # Size in MB
    
    # Create file with specific size (using dd to create random data)
    dd if=/dev/urandom of="$SCREENSHOTS_DIR/$filename" bs=1M count=$size 2>/dev/null
    
    # Calculate date in the past
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS date command
        past_date=$(date -v -${days_ago}d "+%Y%m%d%H%M")
        touch -t "$past_date" "$SCREENSHOTS_DIR/$filename"
    else
        # Linux date command
        past_date=$(date -d "$days_ago days ago" "+%Y%m%d%H%M")
        touch -t "$past_date" "$SCREENSHOTS_DIR/$filename"
    fi
    
    echo "Created: $filename ($days_ago days old, ${size}MB)"
}

# Create test files with various ages and sizes
# Recent screenshots (1-7 days old)
create_dated_file "Screenshot 2024-02-24 at 09.00.00.png" 1 2
create_dated_file "Screenshot 2024-02-23 at 10.15.00.png" 2 1
create_dated_file "Screenshot 2024-02-22 at 11.30.00.png" 3 3
create_dated_file "Screenshot 2024-02-21 at 14.45.00.png" 4 1
create_dated_file "Screen Shot 2024-02-20 at 16.20.00.png" 5 4

# Borderline screenshots (10-15 days old)
create_dated_file "Screenshot 2024-02-15 at 08.30.00.png" 10 5
create_dated_file "Screenshot 2024-02-14 at 09.45.00.png" 11 2
create_dated_file "Screenshot 2024-02-13 at 11.00.00.png" 12 3
create_dated_file "Screenshot 2024-02-12 at 13.15.00.png" 13 6
create_dated_file "Screenshot 2024-02-11 at 15.30.00.png" 14 4

# Old screenshots (15-30 days old)
create_dated_file "Screenshot 2024-02-10 at 10.00.00.png" 15 8
create_dated_file "Screenshot 2024-02-05 at 11.15.00.png" 20 10
create_dated_file "Screenshot 2024-02-01 at 12.30.00.png" 24 7
create_dated_file "Screenshot 2024-01-25 at 14.45.00.png" 28 12
create_dated_file "Screenshot 2024-01-20 at 16.00.00.png" 30 15

# Very old screenshots (31-60 days old)
create_dated_file "Screenshot 2024-01-15 at 09.00.00.png" 35 5
create_dated_file "Screenshot 2024-01-10 at 10.15.00.png" 40 9
create_dated_file "Screenshot 2024-01-05 at 11.30.00.png" 45 11
create_dated_file "Screenshot 2024-01-01 at 12.45.00.png" 50 8
create_dated_file "Screenshot 2023-12-25 at 14.00.00.png" 60 14

echo "Test files created successfully!"
echo "Summary of created files:"
echo "------------------------"
ls -lh "$SCREENSHOTS_DIR"
echo "------------------------"
echo "Files older than 14 days (will be cleaned up):"
find "$SCREENSHOTS_DIR" -type f -mtime +14 -exec ls -lh {} \;