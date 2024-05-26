#!/bin/bash

LOCKFILE="/tmp/brightness_lock"

usage() {
    cat <<EOF
Usage: $0 {up|down} <percentage> [duration] [notify]
  up|down      Mandatory: Direction to change brightness.
  percentage   Mandatory: Integer percentage to increase or decrease brightness.
  duration     Optional: Decimal duration between steps (default is 0.02 seconds).
  notify       Optional: Send notification with final brightness level.
EOF
    exit 1
}

# Check for required parameters
if [[ -z "$1" || -z "$2" ]]; then
    echo "Error: Missing required parameters."
    usage
fi

# Validate the direction parameter
if [[ "$1" != "up" && "$1" != "down" ]]; then
    echo "Error: First parameter must be 'up' or 'down'."
    usage
fi

# Validate the percentage parameter
if ! [[ "$2" =~ ^[0-9]+$ ]]; then
    echo "Error: Percentage must be an integer."
    usage
fi

# Validate the duration parameter if provided
if [[ -n "$3" && ! "$3" =~ ^[0-9]*\.?[0-9]+$ ]]; then
    echo "Error: Duration must be a decimal number."
    usage
fi

# Function to remove the lock file on exit
cleanup() {
    rm -f "$LOCKFILE"
}
trap cleanup EXIT

# Create a lock file to prevent multiple instances
if [ -e "$LOCKFILE" ]; then
    echo "Another instance is running."
    exit 1
else
    touch "$LOCKFILE"
fi

if ! command -v brightnessctl &> /dev/null; then
    echo "Error: 'brightnessctl' could not be found. Please install it first."
    cleanup
    exit 1
fi

STEP_SIZE=2
DELAY=${3:-0.02}
NOTIFY=false

if [[ "$4" == "notify" ]]; then
    NOTIFY=true
fi

current_brightness=$(brightnessctl get)
max_brightness=$(brightnessctl max)
current_brightness_percent=$(( 100 * current_brightness / max_brightness ))

if [[ "$1" == "up" ]]; then
    target_brightness_percent=$(( current_brightness_percent + $2 ))
elif [[ "$1" == "down" ]]; then
    target_brightness_percent=$(( current_brightness_percent - $2 ))
else
    echo "Invalid argument. Use 'up' or 'down' followed by a number."
    cleanup
    exit 1
fi

if [[ $target_brightness_percent -gt 100 ]]; then
    target_brightness_percent=100
elif [[ $target_brightness_percent -lt 0 ]]; then
    target_brightness_percent=0
fi

draw_progress_bar() {
    local progress=$1
    local max_length=50
    local num_hashes=$(( progress * max_length / 100 ))
    local num_spaces=$(( max_length - num_hashes ))
    local bar=$(printf "%0.s#" $(seq 1 $num_hashes))
    local spaces=$(printf "%0.s " $(seq 1 $num_spaces))
    echo -ne "[${bar}${spaces}] ${progress}%\r"
}

if [[ "$1" == "up" ]]; then
    for ((i=current_brightness_percent; i<=target_brightness_percent; i+=STEP_SIZE)); do
        brightnessctl set ${i}% > /dev/null
        draw_progress_bar $i
        sleep $DELAY
    done
else
    for ((i=current_brightness_percent; i>=target_brightness_percent; i-=STEP_SIZE)); do
        brightnessctl set ${i}% > /dev/null
        draw_progress_bar $i
        sleep $DELAY
    done
fi

echo

if $NOTIFY; then
    final_brightness_percent=$(brightnessctl get | awk -v max=$max_brightness '{ printf "%d", 100 * $1 / max }')
    notify-send "Brightness" "Brightness set to ${final_brightness_percent}%"
fi

cleanup

