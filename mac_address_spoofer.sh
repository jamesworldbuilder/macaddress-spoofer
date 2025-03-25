#!/bin/bash
##############################################
# MAC Address Spoofer Script
# Purpose: Spoof and manage MAC addresses on network interfaces
# Features:
# - Automatic interface detection
# - Random MAC address generation
# - Original MAC address backup and restoration
# - Network disconnection handling
##############################################

# Get a network interface (not necessarily active)
get_interface() {
    if [ -n "$user_interface" ]; then
        # Use user-specified interface if provided
        interface="$user_interface"
        if ! ip link show "$interface" >/dev/null 2>&1; then
            echo "ERROR: Specified network interface '$interface' not found"
            exit 1
        fi
    else
        # Otherwise, auto-detect the first non-loopback interface
        interface=$(ip link | grep -E '^[0-9]:' | grep -v 'lo:' | awk '{print $2}' | sed 's/://' | head -n1)
        if [ -z "$interface" ]; then
            echo "ERROR: No suitable network interface found"
            exit 1
        fi
    fi
    echo "Selected network interface: $interface"
}

# Disconnect from network
disconnect_network() {
    if command -v nmcli >/dev/null 2>&1; then
        local active_con=$(nmcli -t -f NAME con show --active | head -n1)
        if [ -n "$active_con" ]; then
            nmcli con down id "$active_con" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo "Successfully disconnected from network"
            else
                echo "WARNING: Failed to disconnect from network using 'nmcli' - Proceeding anyway..."
            fi
        else
            echo "No active connection found - Proceeding..."
        fi
    else
        sudo ip link set "$interface" down >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "Successfully disconnected from network via 'ip link'"
        else
            echo "WARNING: Failed to disconnect from network using 'ip link' - Proceeding anyway..."
        fi
    fi
    return 0
}

# Disconnect with retries
disconnect_with_retries() {
    max_disconnect_attempts=5
    disconnect_attempt=1

    while ip route get 9.9.9.9 >/dev/null 2>&1; do # Quad9 public DNS service
        echo "Network connection detected - Disconnecting...(attempt $disconnect_attempt of $max_disconnect_attempts)"
        if [ $disconnect_attempt -gt $max_disconnect_attempts ]; then
            echo "WARNING: Failed to disconnect after $max_disconnect_attempts attempts - Proceeding anyway..."
            break
        fi
        
        disconnect_network
        disconnect_attempt=$((disconnect_attempt + 1))
        read -t 1 -p "" </dev/null
    done
}

# Display and apply a new MAC address
apply_mac() {
    interface=$1
    mac_address=$2

    sudo ip link set "$interface" down || {
        echo "ERROR: Failed to disable network interface '$interface'"
        exit 1
    }

    sudo ip link set "$interface" address "$mac_address" || {
        echo "ERROR: Failed to set new MAC address"
        exit 1
    }

    sudo ip link set "$interface" up || {
        echo "ERROR: Failed to bring network interface '$interface' back up"
        exit 1
    }

    echo "MAC address for '$interface' changed to: $mac_address"
}

# Generate random MAC addresses to an array
generate_mac_list() {
    mac_array=()  # Clear/init array
    echo "Generating a list of random MAC addresses to select from...(attempt $attempt of $max_attempts)"
    for i in {1..5}; do
        mac=$(printf '02:%02X:%02X:%02X:%02X:%02X' \
            $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)) \
            $((RANDOM % 256)) $((RANDOM % 256)))
        mac_array+=("$mac")  # Add MAC to array
    done
    echo "Generated MAC addresses:"
    printf '%s\n' "${mac_array[@]}"  # Print the list
}

# Revert to original MAC address
revert_mac() {
    get_interface
    backup_dir="$HOME/.config/macaddr_backup"
    # Look for the most recent backup file for this interface
    backup_file=$(ls -t "$backup_dir/${interface}_"* 2>/dev/null | head -n1)

    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        echo "ERROR: No backup file found for '$interface' in '$backup_dir' - Cannot revert"
        exit 1
    fi

    original_mac=$(cat "$backup_file")
    if [[ ! $original_mac =~ ^([A-Fa-f0-9]{2}:){5}[A-Fa-f0-9]{2}$ ]]; then
        echo "ERROR: Invalid MAC address format in backup file '$backup_file'"
        exit 1
    fi

    disconnect_with_retries

    apply_mac "$interface" "$original_mac"

    current_mac=$(ip link show "$interface" | awk '/ether/ {print $2}')
    if [ "${current_mac,,}" = "${original_mac,,}" ]; then
        echo "MAC address successfully reverted to original for '$interface'"
        echo "Restored from: $backup_file"
        echo "Current MAC: $current_mac"
        echo -e "\ndone"
    else
        echo "ERROR: Failed to revert MAC address"
        echo "Current MAC: $current_mac"
        echo "Expected MAC: $original_mac"
        exit 1
    fi
}

# Main function for spoofing
main() {
    echo "Spoofing MAC address..."

    command -v ip >/dev/null 2>&1 || { echo "ERROR: 'ip' is required but not installed"; exit 1; }

    disconnect_with_retries

    get_interface

    # Capture and store the original MAC address in backup file (only if not already backed up)
    original_mac=$(ip link show "$interface" | awk '/ether/ {print $2}')
    if [ -z "$original_mac" ]; then
        echo "WARNING: Could not retrieve original MAC address for '$interface' - Proceeding anyway..."
    else
        echo "Original MAC address: $original_mac"
        backup_dir="$HOME/.config/macaddr_backup"
        mkdir -p "$backup_dir" 2>/dev/null || true
        # Check if any backup exists for the interface
        if ls "$backup_dir/${interface}_"* >/dev/null 2>&1; then
            echo "Original MAC address backup for '$interface' detected in '$backup_dir' - Proceeding..."
            backup_file=$(ls -t "$backup_dir/${interface}_"* | head -n1)
        else
            # Create a new backup file with creation date
            timestamp=$(date +"%Y-%m-%d")
            backup_file="$backup_dir/${interface}_${timestamp}"
            echo "$original_mac" > "$backup_file" 2>/dev/null || {
                echo "WARNING: Failed to backup original MAC address in '$backup_file' - Proceeding anyway..."
            }
            chmod 600 "$backup_file" 2>/dev/null || true
            echo "Original MAC address saved to '$backup_file' for future restoration"
        fi
    fi

    # Generate and select new MAC address - Retry if new MAC address is invalid
    max_attempts=3
    attempt=1
    valid_mac=false

    while [ "$valid_mac" = false ] && [ $attempt -le $max_attempts ]; do
        
        generate_mac_list

        if [ ${#mac_array[@]} -eq 0 ]; then
            echo "ERROR: MAC address list is empty"
            attempt=$((attempt + 1))
            continue
        fi

        selected_mac=${mac_array[$((RANDOM % 5))]}  # Pick random from 0-4
        echo "Selected MAC address: $selected_mac"

        if [[ $selected_mac =~ ^([A-F0-9]{2}:){5}[A-F0-9]{2}$ ]]; then
            valid_mac=true
        else
            echo "Invalid MAC address format detected - Retrying..."
            attempt=$((attempt + 1))
            if [ $attempt -gt $max_attempts ]; then
                echo "ERROR: Failed to generate valid MAC address after $max_attempts attempts"
                exit 1
            fi
            read -t 1 -p "" </dev/null
        fi
    done

    if [ "$valid_mac" = false ]; then
        echo "ERROR: Failed to generate a valid MAC address list after $max_attempts attempts"
        exit 1
    fi

    apply_mac "$interface" "$selected_mac"

    current_mac=$(ip link show "$interface" | awk '/ether/ {print $2}')
    if [ "${current_mac,,}" = "${selected_mac,,}" ]; then
        echo "MAC address spoofing completed successfully for '$interface'"
        echo "Previous MAC: $original_mac"
        echo "New MAC: $current_mac"
        echo "You can now connect to a network with the new spoofed MAC address"
        echo "To revert to the original MAC, run: $0 --revert [--interface=$interface]"
        echo "WARNING: This doesn't affect the 'permaddr' (permanent MAC address),"
        echo "         which remains visible to low-level tools (e.g., 'ip link'),"
        echo "         but network traffic uses the spoofed active MAC address"
        echo -e "\ndone"
    else
        echo "ERROR: MAC address change failed"
        echo "Previous MAC: $original_mac"
        echo "Current MAC: $current_mac"
        echo "Expected MAC: $selected_mac"
        exit 1
    fi
}

# Parse command-line flags
revert_mode=false
while [ $# -gt 0 ]; do
    case "$1" in
        --interface=*)
            user_interface="${1#*=}"
            if [ -z "$user_interface" ]; then
                echo "ERROR: No network interface specified with '--interface='"
                exit 1
            fi
            shift
            ;;
        --revert)
            revert_mode=true
            shift
            ;;
        *)
            echo "ERROR: Unknown flag: $1"
            echo "Usage: $0 [--interface=<network_interface>] [--revert]"
            exit 1
            ;;
    esac
done

# Decide whether to spoof or revert
if [ "$revert_mode" = true ]; then
    revert_mac
else
    main
fi
