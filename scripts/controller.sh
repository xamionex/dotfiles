#!/usr/bin/env bash

# Gamepad Combo Executor for Wayland/KDE Plasma
# Supports multiple combos, auto-redetects controllers
# Requires: evtest, kdotool, bluetoothctl, notify-send

# ======================================== USER CONFIGURATION ========================================

# Define your combos (name: button codes separated by spaces)
declare -A combos=(
    ["kill_app"]="317 318 310 311" # Combo 1: L3 + R3 + LB + RB (kill app)
    ["disconnect"]="316 307"       # Combo 2: GUIDE + X (disconnect controller)
    ["screenshot"]="315 314"       # Combo 3: START + BACK (screenshot)
)

# Map combo names to action functions
declare -A combo_actions=(
    ["kill_app"]="_kill_app"
    ["disconnect"]="_disconnect"
    ["screenshot"]="_screenshot"
)

# Define button names for logging
declare -A button_names=(
    [304]="A"       # PS: ❌
    [305]="B"       # PS: ⭕
    [307]="X"       # PS: 🔺
    [308]="Y"       # PS: 🟥
    [310]="LB"
    [311]="RB"
    [312]="LT"
    [313]="RT"
    [314]="BACK"    # PS: Select
    [315]="START"   # PS: Options
    [316]="GUIDE"   # LOGO/PS/XBOX Button
    [317]="L3"
    [318]="R3"
    [16]="DPAD_X"
    [17]="DPAD_Y"
)

parse_flags() {
  # default value
  OPENRGB=false

  # parse options
  while getopts "o" opt; do
    case "$opt" in
      o) OPENRGB=true ;;
      ?) echo "Invalid option: -$OPTARG" >&2 ;;
    esac
  done
}

# Define actions for each combo
_kill_app() {
    if [[ -n "$win_id" ]]; then
        if [[ -n "$pid" ]]; then
            # Check if this PID or any of its children is running "shadps4"
            kill -9 "$pid" 2>/dev/null
            echo "Killed application with PID $pid"
            #notify-send "Gamepad Combo" "Killed application (PID $pid)" 2>/dev/null
#             if pstree -p "$pid" | grep -q "shadps4"; then
#                 echo "shadps4 detected, sending F4"
#                 ydotool key 62  # 62 = F4
#                 notify-send "Gamepad Combo" "Sent F4 to shadps4 window" 2>/dev/null
#             else
#                 kill -9 "$pid" 2>/dev/null
#                 echo "Killed application with PID $pid"
#                 notify-send "Gamepad Combo" "Killed application (PID $pid)" 2>/dev/null
#             fi
        else
            echo "Could not get PID for window $win_id"
            notify-send "Gamepad Combo" "Could not get PID for window" 2>/dev/null
        fi
    else
        echo "No active window found"
        notify-send "Gamepad Combo" "No active window found" 2>/dev/null
    fi
}

get_bt_mac_from_dev() {
    local device="$1" # Expecting something like /dev/input/event27

    if [[ -z "$device" ]]; then
        echo "Error: No device path provided." >&2
        return 1
    fi

    if [[ ! -e "$device" ]]; then
        echo "Error: Device $device does not exist." >&2
        return 1
    fi

    # Get the udev path for the input device
    local udev_path=$(udevadm info -q path -n "$device")

    if [[ -z "$udev_path" ]]; then
        echo "Error: Could not get udev path for $device." >&2
        return 1
    fi

    # Trace up the device tree to find a Bluetooth device
    # We look for a device with a 'bdaddr' (Bluetooth Device Address) attribute
    # or a 'bluetooth' directory in its sysfs path.
    local current_path="/sys${udev_path}"

    local mac_address=$(cat ${current_path}/device/uniq)

    if [[ -n "$mac_address" ]]; then
        echo "$mac_address"
        return 0
    else
        echo "Could not determine Bluetooth MAC address for $device. It might not be a Bluetooth device, or its MAC address is not directly exposed via sysfs from this input event." >&2
        return 1
    fi
}

_disconnect() {
    CURRENT_BT_MAC=$(get_bt_mac_from_dev "$device")
    if [[ -n "$CURRENT_BT_MAC" ]]; then
        echo "Disconnecting Bluetooth device $CURRENT_BT_MAC"
        notify-send "Gamepad Combo" "Disconnecting controller $CURRENT_BT_MAC"
        bluetoothctl disconnect "$CURRENT_BT_MAC" 2>/dev/null
    fi
#     else
#         echo "Couldn't get MAC Address for: $device"
#         # fallback to disconnect all
#         connected_devices=$(bluetoothctl devices Connected | grep Device | awk '{print $2}')
#         if [[ -z "$connected_devices" ]]; then
#             echo "No connected Bluetooth devices found."
#             notify-send "Gamepad Combo" "No connected Bluetooth devices found."
#             return 1
#         fi
#
#         for mac in $connected_devices; do
#             echo "Disconnecting Bluetooth device $mac"
#             notify-send "Gamepad Combo" "Disconnecting controller $mac"
#             bluetoothctl disconnect "$mac" 2>/dev/null
#         done
#     fi
}

_screenshot() {
    ydotool key 88:1 88:0 # F12
    ydotool key 54:1 99:1 99:0 54:0 # RShift+PrtSc
}

restart_openrgb() {
    ! $OPENRGB && echo "Skipping OpenRGB service restart because of no flag" && return
    echo "Restarting OpenRGB service due to controller connection..."
    systemctl --user restart openrgb.service
}
# ======================================== END CONFIGURATION ========================================

# Function to get button name
get_button_name() {
    local code=$1
    if [[ -n "${button_names[$code]}" ]]; then
        echo "${button_names[$code]}"
    else
        echo "BTN_$code"
    fi
}

# Function to start monitoring a device
start_monitor_device() {
    CURRENT_BT_MAC=""
    local device=$1
    (
        echo "Starting monitor for device: $device"
        
        # Initialize state tracking for this device
        declare -A button_states=()
        for combo_name in "${!combos[@]}"; do
            for btn in ${combos[$combo_name]}; do
                button_states[$btn]=0
            done
        done
        
        # Track DPAD states for this device
        declare -A dpad_states=([16]=0 [17]=0)
        declare -A last_dpad_values=([16]=0 [17]=0)
        declare -A dpad_map=(
            ["16_-1"]="DPAD_LEFT"
            ["16_1"]="DPAD_RIGHT"
            ["17_-1"]="DPAD_UP"
            ["17_1"]="DPAD_DOWN"
        )
        declare -A current_direction=([16]="" [17]="")
        
        # Run evtest for this device
        evtest "$device" | while read -r line; do
            # Parse relevant events
            if [[ "$line" =~ Event:\ .*type\ (1|3).*code\ ([0-9]+).*value\ (-?[0-9]+) ]]; then
                event_type=${BASH_REMATCH[1]}
                code=${BASH_REMATCH[2]}
                value=${BASH_REMATCH[3]}

                # Handle button events
                if [[ "$event_type" == "1" ]]; then
                    btn_name=$(get_button_name "$code")
                    action="RELEASED"
                    if [[ "$value" == "1" ]]; then
                        action="PRESSED"
                    fi
                    echo "[$device][$btn_name][$action]"
                    
                    # Update state if in any combo
                    if [[ -n "${button_states[$code]}" ]]; then
                        button_states[$code]="$value"
                        
                        # Check all combos
                        for combo_name in "${!combos[@]}"; do
                            all_pressed=1
                            for btn in ${combos[$combo_name]}; do
                                if [[ "${button_states[$btn]}" != "1" ]]; then
                                    all_pressed=0
                                    break
                                fi
                            done
                            
                            if [[ $all_pressed -eq 1 ]]; then
                                echo "COMBO DETECTED: $combo_name"
                                win_id=$(kdotool getactivewindow 2>/dev/null)
                                pid=$(kdotool getwindowpid "$win_id" 2>/dev/null)

#                                 if pstree -p "$pid" | grep -q "Magicka"; then
#                                     echo "Magicka detected, skipping"
#                                 else
                                ${combo_actions[$combo_name]}
#                                 fi
                                
                                # Reset states for this combo
                                for btn in ${combos[$combo_name]}; do
                                    button_states[$btn]=0
                                done
                            fi
                        done
                    fi
                
                # Handle DPAD events
                elif [[ "$event_type" == "3" ]] && [[ "$code" == "16" || "$code" == "17" ]]; then
                    if [[ "$value" == "0" ]]; then
                        if [[ -n "${current_direction[$code]}" ]]; then
                            echo "[$device][${current_direction[$code]}][RELEASED]"
                            current_direction[$code]=""
                        fi
                    else
                        key="${code}_${value}"
                        if [[ -n "${dpad_map[$key]}" ]]; then
                            if [[ -n "${current_direction[$code]}" ]]; then
                                echo "[$device][${current_direction[$code]}][RELEASED]"
                            fi
                            new_direction=${dpad_map[$key]}
                            echo "[$device][$new_direction][PRESSED]"
                            current_direction[$code]="$new_direction"
                        fi
                    fi
                    last_dpad_values[$code]="$value"
                fi
            fi
        done
        
        echo "Device $device disconnected or monitor exited"
    ) &
    echo $!  # Return PID of background process
}

# Main loop to detect and monitor controllers
main_loop() {
    declare -A active_pids  # device -> pid
    declare -A device_pids  # pid -> device (for cleanup)
    
    echo "Controller monitor running. Press Ctrl+C to exit."
    echo "Listening for combos:"
    for combo_name in "${!combos[@]}"; do
        combo_names=()
        for btn in ${combos[$combo_name]}; do
            combo_names+=("$(get_button_name "$btn")")
        done
        combo_str=$(IFS=" + "; echo "${combo_names[*]}")
        echo "  - $combo_name: $combo_str"
    done
    
    while true; do
        # Find all joystick devices
        devices=()
        for dev in /dev/input/event*; do
            if udevadm info --query=property --name="$dev" | grep -q ID_INPUT_JOYSTICK=1; then
                devices+=("$dev")
            fi
        done
        
        # Start monitoring new devices
        for device in "${devices[@]}"; do
            if [[ -z "${active_pids[$device]}" ]]; then
                start_monitor_device "$device"
                pid=$!
                active_pids[$device]="$pid"
                device_pids[$pid]="$device"
                echo "Started monitoring PID $pid for $device"

                # Restart OpenRGB on new device connection
                restart_openrgb
            fi
        done
        
        # Check for exited monitors
        for pid in "${!device_pids[@]}"; do
            if ! kill -0 "$pid" 2>/dev/null; then
                device="${device_pids[$pid]}"
                echo "Monitor for $device (PID $pid) exited"
                unset active_pids["$device"]
                unset device_pids["$pid"]
            fi
        done
        
        # Remove stale devices
        for device in "${!active_pids[@]}"; do
            if [[ ! -e "$device" ]]; then
                pid="${active_pids[$device]}"
                echo "Device $device removed, killing monitor PID $pid"
                kill -9 "$pid" 2>/dev/null
                unset active_pids["$device"]
                unset device_pids["$pid"]
            fi
        done
        
        sleep 5  # Check for new devices every 5 seconds
    done
}

# Cleanup on exit
cleanup() {
    echo "Exiting... Killing all monitoring processes"
    for pid in "${!device_pids[@]}"; do
        kill "$pid" 2>/dev/null
    done
    exit
}
trap cleanup SIGINT SIGTERM

# Start the main loop
main_loop
