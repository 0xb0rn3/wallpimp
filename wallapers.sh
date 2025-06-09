#!/usr/bin/env bash

# Wallpaper Slideshow Script for OpenBox and XFCE
# This script automatically cycles through wallpapers in a specified directory
# Compatible with both OpenBox (using feh) and XFCE (using xfconf-query)

# Configuration section - customize these variables
WALLPAPER_DIR="$HOME/Pictures/wallpapers"  # Change this to your wallpaper directory
INTERVAL=300  # Time between wallpaper changes in seconds (300 = 5 minutes)
RANDOM_ORDER=true  # Set to false for alphabetical order
LOG_FILE="$HOME/.wallpaper_slideshow.log"
PID_FILE="$HOME/.wallpaper_slideshow.pid"

# Function to log messages with timestamps
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to detect the current desktop environment
detect_desktop_environment() {
    if [ "$XDG_CURRENT_DESKTOP" = "XFCE" ] || [ "$DESKTOP_SESSION" = "xfce" ]; then
        echo "xfce"
    elif [ -n "$OPENBOX_VERSION" ] || pgrep -x "openbox" > /dev/null; then
        echo "openbox"
    elif command -v xfconf-query > /dev/null && xfconf-query -c xfce4-desktop -l > /dev/null 2>&1; then
        echo "xfce"
    elif command -v feh > /dev/null; then
        echo "openbox"  # Default to openbox if feh is available
    else
        echo "unknown"
    fi
}

# Function to set wallpaper in XFCE
set_wallpaper_xfce() {
    local wallpaper_path="$1"
    
    # XFCE uses xfconf-query to manage desktop properties
    # We need to set the wallpaper for all monitors and workspaces
    
    # Get all available monitors
    local monitors=$(xfconf-query -c xfce4-desktop -l | grep -E "backdrop/screen.*/monitor.*image-path$" | head -10)
    
    if [ -z "$monitors" ]; then
        # Fallback: try to set for default screen/monitor configuration
        xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "$wallpaper_path" 2>/dev/null
        xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/image-path -s "$wallpaper_path" 2>/dev/null
    else
        # Set wallpaper for all detected monitor configurations
        while IFS= read -r monitor_path; do
            xfconf-query -c xfce4-desktop -p "$monitor_path" -s "$wallpaper_path" 2>/dev/null
        done <<< "$monitors"
    fi
    
    log_message "XFCE: Set wallpaper to $wallpaper_path"
}

# Function to set wallpaper in OpenBox (using feh)
set_wallpaper_openbox() {
    local wallpaper_path="$1"
    
    # feh is the most common wallpaper setter for OpenBox
    # --bg-scale scales the image to fit the screen while maintaining aspect ratio
    feh --bg-scale "$wallpaper_path"
    
    # Save the feh command to ~/.fehbg for persistence across sessions
    echo "feh --bg-scale '$wallpaper_path'" > "$HOME/.fehbg"
    chmod +x "$HOME/.fehbg"
    
    log_message "OpenBox: Set wallpaper to $wallpaper_path"
}

# Function to set wallpaper based on desktop environment
set_wallpaper() {
    local wallpaper_path="$1"
    local desktop_env="$2"
    
    case "$desktop_env" in
        "xfce")
            set_wallpaper_xfce "$wallpaper_path"
            ;;
        "openbox")
            set_wallpaper_openbox "$wallpaper_path"
            ;;
        *)
            log_message "ERROR: Unknown desktop environment: $desktop_env"
            return 1
            ;;
    esac
}

# Function to get list of wallpaper files
get_wallpaper_list() {
    # Find all common image formats in the wallpaper directory
    find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.bmp" -o -iname "*.gif" -o -iname "*.tiff" -o -iname "*.webp" \) 2>/dev/null
}

# Function to shuffle wallpaper list if random order is enabled
process_wallpaper_list() {
    local wallpaper_list="$1"
    
    if [ "$RANDOM_ORDER" = true ]; then
        echo "$wallpaper_list" | shuf
    else
        echo "$wallpaper_list" | sort
    fi
}

# Function to start the slideshow daemon
start_slideshow() {
    # Check if wallpaper directory exists
    if [ ! -d "$WALLPAPER_DIR" ]; then
        echo "Error: Wallpaper directory '$WALLPAPER_DIR' does not exist."
        echo "Please update the WALLPAPER_DIR variable in the script."
        exit 1
    fi
    
    # Detect desktop environment
    local desktop_env=$(detect_desktop_environment)
    if [ "$desktop_env" = "unknown" ]; then
        echo "Error: Could not detect compatible desktop environment (XFCE or OpenBox)."
        echo "Please ensure you have xfconf-query (XFCE) or feh (OpenBox) installed."
        exit 1
    fi
    
    echo "Detected desktop environment: $desktop_env"
    
    # Check for required commands
    case "$desktop_env" in
        "xfce")
            if ! command -v xfconf-query > /dev/null; then
                echo "Error: xfconf-query not found. Please install xfce4-settings."
                exit 1
            fi
            ;;
        "openbox")
            if ! command -v feh > /dev/null; then
                echo "Error: feh not found. Please install feh package."
                exit 1
            fi
            ;;
    esac
    
    # Get wallpaper list
    local wallpapers=$(get_wallpaper_list)
    if [ -z "$wallpapers" ]; then
        echo "Error: No wallpaper files found in '$WALLPAPER_DIR'."
        echo "Supported formats: JPG, PNG, BMP, GIF, TIFF, WebP"
        exit 1
    fi
    
    local wallpaper_count=$(echo "$wallpapers" | wc -l)
    echo "Found $wallpaper_count wallpaper(s) in $WALLPAPER_DIR"
    echo "Slideshow interval: $INTERVAL seconds"
    echo "Random order: $RANDOM_ORDER"
    
    # Save PID for stop functionality
    echo $$ > "$PID_FILE"
    
    log_message "Starting wallpaper slideshow (PID: $$, Desktop: $desktop_env, Interval: ${INTERVAL}s, Random: $RANDOM_ORDER)"
    
    # Main slideshow loop
    while true; do
        local processed_wallpapers=$(process_wallpaper_list "$wallpapers")
        
        while IFS= read -r wallpaper; do
            if [ -f "$wallpaper" ]; then
                set_wallpaper "$wallpaper" "$desktop_env"
                echo "Current wallpaper: $(basename "$wallpaper")"
                
                # Sleep for the specified interval
                sleep "$INTERVAL"
            fi
        done <<< "$processed_wallpapers"
    done
}

# Function to stop the slideshow
stop_slideshow() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            echo "Stopped wallpaper slideshow (PID: $pid)"
            log_message "Slideshow stopped (PID: $pid)"
        else
            echo "Slideshow process not running"
        fi
        rm -f "$PID_FILE"
    else
        echo "No slideshow process found"
    fi
}

# Function to check slideshow status
status_slideshow() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Wallpaper slideshow is running (PID: $pid)"
            echo "Log file: $LOG_FILE"
            echo "Configuration:"
            echo "  Wallpaper directory: $WALLPAPER_DIR"
            echo "  Interval: $INTERVAL seconds"
            echo "  Random order: $RANDOM_ORDER"
        else
            echo "Slideshow process not running (stale PID file)"
            rm -f "$PID_FILE"
        fi
    else
        echo "Wallpaper slideshow is not running"
    fi
}

# Function to show usage information
show_usage() {
    echo "Usage: $0 [start|stop|status|help]"
    echo ""
    echo "Commands:"
    echo "  start   - Start the wallpaper slideshow"
    echo "  stop    - Stop the wallpaper slideshow"
    echo "  status  - Show slideshow status"
    echo "  help    - Show this help message"
    echo ""
    echo "Configuration:"
    echo "  Edit the script to modify:"
    echo "  - WALLPAPER_DIR: Directory containing wallpapers"
    echo "  - INTERVAL: Time between wallpaper changes (seconds)"
    echo "  - RANDOM_ORDER: true for random, false for alphabetical"
    echo ""
    echo "The script automatically detects XFCE or OpenBox environments."
}

# Main script logic
case "${1:-start}" in
    "start")
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "Wallpaper slideshow is already running"
            exit 1
        fi
        start_slideshow
        ;;
    "stop")
        stop_slideshow
        ;;
    "status")
        status_slideshow
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        echo "Invalid command: $1"
        show_usage
        exit 1
        ;;
esac
