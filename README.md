# MAC Address Spoofer Script

## Purpose
The `MAC Address Spoofer Script` (`mac_address_spoofer.sh`) is a Bash utility designed to spoof (change) the MAC address of a network interface controller (NIC) on most Linux systems and provides an option to revert to the original MAC address. It aims to enhance privacy by allowing users to temporarily mask their device’s hardware MAC address while preserving the ability to restore the original. It’s recommended to run the script before establishing a network connection, though it will still function if the system is already connected.

## What It Does
This script performs the following key functions:
- **Spoofs a MAC Address**: Generates a random MAC address and applies it to a specified or auto-detected network interface (e.g., `eth0`, `wlan0`, `enp1s0`, etc.).
- **Backs Up the Original MAC**: Stores the original MAC address in `~/.config/macaddr_backup/` with a creation date suffix (e.g., `eth0_2025-03-23`), but only if no backup exists yet for the selected network interface. Backup file permissions are isolated to the current user. 
- **Option to Restore Original MAC Address**: Restores the original MAC address of the selected network interface from the backup file when the script is run with the `--revert` flag.
- **Purpose-Specific Network Handling and MAC Format Validation**: Disconnects the network before changing the MAC address, retries if necessary, checks network connectivity using [Quad9’s public DNS server](https://www.quad9.net/) (`9.9.9.9`), and validates the new MAC address format.

## Requirements
- **Operating System**: Linux environment.
- **Bash Shell**: Compatible with Bash 4.0 or later.
- **Dependencies**:
  - `ip` (from `iproute2` package, usually pre-installed).
  - Optional: `nmcli` (from `NetworkManager`, recommended for cleaner network disconnection if available).
- **Permissions**: Requires `sudo` privileges to modify network interface settings.

## How to Use
1. **Make it Executable**: First, make sure it's executable with:
   ```bash
   chmod +x mac_address_spoofer.sh
   ```
2. **Run the Script**:
   - **Spoof a MAC Address**:
     ```bash
     ./mac_address_spoofer.sh [--interface=<network_interface>]
     ```
     - If `--interface` is omitted, the script auto-detects and selects the first non-loopback network interface (e.g., `eth0`, `wlan0`, etc.), excluding the loopback interface (e.g., `lo`).
     - Example: `./mac_address_spoofer.sh --interface=eth0`
   - **Revert to Original MAC Address**:
     ```bash
     ./mac_address_spoofer.sh --revert [--interface=<network_interface>]
     ```
     - If `--interface` is omitted, the script auto-detects and selects the first non-loopback network interface (e.g., `eth0`, `wlan0`, etc.), excluding the loopback interface (e.g., `lo`). The script then looks for a backup file in the `~/.config/macaddr_backup/` directory [matching the pattern](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap09.html) `<network_interface>_*` (e.g., `eth0_2025-03-23`). 

        It's recommended that if you spoofed a specific interface, to specify the same one when using the `--revert` flag, because if the auto-detected interface doesn’t match the one you previously spoofed, it fails with a "`No backup file found`" error. This is a limitation of the auto-detection logic, not a bug— the script assumes consistency between spoofing and reverting. 

        Issues arise if suppose the script previously spoofed the MAC address for the `wlan0` interface and saved the backup file as `wlan0_2025-03-23`, but `eth0` is the first interface detected when running `./mac_address_spoofer.sh --revert` without specifying the `--interface` flag. Then the script will look for a backup filename beginning with "`eth0_`" instead or "`wlan0_`".
     - Example: 

       (recommended)
       ```bash
       ./mac_address_spoofer.sh --revert --interface=eth0 
       ``` 
       or
       ```bash
       ./mac_address_spoofer.sh --revert

## Possible Outputs
### Successful/Expected Outputs:
#### Spoofing a MAC Address (First Run)
```plaintext
Spoofing MAC address...
Network connection detected - Disconnecting...(attempt 1 of 5)
Successfully disconnected from network
Selected network interface: eth0
Original MAC address: 00:11:22:33:44:55
Original MAC address saved to '/home/user/.config/macaddr_backup/eth0_2025-03-23' for future restoration
Generating a list of random MAC addresses to select from...(attempt 1 of 3)
Generated MAC addresses:
02:AB:CD:EF:12:34
02:56:78:90:AB:CD
02:DE:AD:BE:EF:12
02:34:56:78:90:AB
02:EF:CD:AB:12:34
Selected MAC address: 02:AB:CD:EF:12:34
MAC address for 'eth0' changed to: 02:AB:CD:EF:12:34
MAC address spoofing completed successfully for 'eth0'
Previous MAC: 00:11:22:33:44:55
New MAC: 02:AB:CD:EF:12:34
You can now connect to a network with the new spoofed MAC address
To revert to the original MAC, run: ./mac_address_spoofer.sh --revert [--interface=eth0]
WARNING: This doesn't affect the 'permaddr' (permanent MAC address),
         which remains visible to low-level tools (e.g., 'ip link'),
         but network traffic uses the spoofed active MAC address

done
```

#### Spoofing a MAC Address (Subsequent Run - Backup Exists)
```plaintext
Spoofing MAC address...
Selected network interface: eth0
Original MAC address: 00:11:22:33:44:55
Original MAC address backup for 'eth0' detected in '/home/user/.config/macaddr_backup' - Proceeding...
Generating a list of random MAC addresses to select from...(attempt 1 of 3)
Generated MAC addresses:
02:12:34:56:78:90
02:AB:CD:EF:12:34
02:56:78:90:AB:CD
02:DE:AD:BE:EF:12
02:EF:CD:AB:12:34
Selected MAC address: 02:12:34:56:78:90
MAC address for 'eth0' changed to: 02:12:34:56:78:90
MAC address spoofing completed successfully for 'eth0'
Previous MAC: 00:11:22:33:44:55
New MAC: 02:12:34:56:78:90
You can now connect to a network with the new spoofed MAC address
To revert to the original MAC, run: ./mac_address_spoofer.sh --revert [--interface=eth0]
WARNING: This doesn't affect the 'permaddr' (permanent MAC address),
         which remains visible to low-level tools (e.g., 'ip link'),
         but network traffic uses the spoofed active MAC address

done
```

#### Reverting to Original MAC Address
```plaintext
Selected network interface: eth0
MAC address successfully reverted to original for 'eth0'
Restored from: /home/user/.config/macaddr_backup/eth0_2025-03-23
Current MAC: 00:11:22:33:44:55

done
```

### Error Outputs:

#### No Suitable Network Interface Found (Auto-Detection)
```plaintext
Spoofing MAC address...
ERROR: No suitable network interface found
```
- **Cause**: No non-loopback network interfaces (e.g., `eth0`, `wlan0`, etc.) were detected.
- **Fix**: Specify an interface with `--interface=<name>` or ensure a network interface exists (check with `ip link show`).

#### Specified Network Interface Not Found (Manual)
```plaintext
Spoofing MAC address...
ERROR: Specified network interface 'eth99' not found
```
- **Cause**: The network interface '`eth99`', specified with the `--interface=eth99` flag, doesn’t exist.
- **Fix**: Use a valid interface name (check with `ip link show`).

#### No Network Interface Specified (Manual)
```plaintext
ERROR: No network interface specified with '--interface='
```
- **Cause**: The `--interface` flag was used without a value (e.g., `--interface=`).
- **Fix**: Provide a value (e.g., `--interface=eth0`).

#### Unknown Flag
```plaintext
ERROR: Unknown flag: --foo
Usage: ./mac_address_spoofer.sh [--interface=<network_interface>] [--revert]
```
- **Cause**: An invalid flag was used (e.g., `--foo`).
- **Fix**: Use only supported flags `--interface` or `--revert`.

#### Failed to Disable Network Interface
```plaintext
Spoofing MAC address...
Selected network interface: eth0
Original MAC address: 00:11:22:33:44:55
Original MAC address saved to '/home/user/.config/macaddr_backup/eth0_2025-03-23' for future restoration
Generating a list of random MAC addresses to select from...(attempt 1 of 3)
List of generated MAC addresses saved to temporary file: /tmp/tmp.XYZ789
02:AB:CD:EF:12:34
Selected MAC address: 02:AB:CD:EF:12:34
ERROR: Failed to disable network interface 'eth0'
```
- **Cause**: The script tried to disable the selected network interface (with `sudo ip link set eth0 down`) and it failed (e.g., due to insufficient permissions or other interface issues).
- **Fix**: Try running the script with `sudo` or check interface status (with `ip link show`) for other possible issues.

#### Failed to Bring Network Interface Back Up
```plaintext
Spoofing MAC address...
Selected network interface: eth0
Original MAC address: 00:11:22:33:44:55
Original MAC address saved to '/home/user/.config/macaddr_backup/eth0_2025-03-23' for future restoration
Generating a list of random MAC addresses to select from...(attempt 1 of 3)
List of generated MAC addresses saved to temporary file: /tmp/tmp.XYZ789
02:AB:CD:EF:12:34
Selected MAC address: 02:AB:CD:EF:12:34
ERROR: Failed to bring network interface 'eth0' back up
```
- **Cause**: The script tried to enable the selected network interface (with `sudo ip link set eth0 up`) and failed (e.g., due to NIC hardware or driver issues).
- **Fix**: Check interface status (with `ip link show`) and system logs (with `dmesg`). 

#### Failed to Set New MAC Address (Verification)
```plaintext
Spoofing MAC address...
Selected network interface: eth0
Original MAC address: 00:11:22:33:44:55
Original MAC address saved to '/home/user/.config/macaddr_backup/eth0_2025-03-23' for future restoration
Generating a list of random MAC addresses to select from...(attempt 1 of 3)
Generated MAC addresses:
02:AB:CD:EF:12:34
02:56:78:90:AB:CD
02:DE:AD:BE:EF:12
02:34:56:78:90:AB
02:EF:CD:AB:12:34
Selected MAC address: 02:AB:CD:EF:12:34
ERROR: Failed to set new MAC address
```
- **Cause**: The script tried running `sudo ip link set eth0 address ...` and it failed (e.g., due to NIC hardware not supporting MAC address spoofing or driver ignored the change).
- **Fix**: Verify NIC hardware support for MAC spoofing. Try running the script with `sudo`.

#### MAC Address Change Failed (Verification)
```plaintext
Spoofing MAC address...
Selected network interface: eth0
Original MAC address: 00:11:22:33:44:55
Original MAC address saved to '/home/user/.config/macaddr_backup/eth0_2025-03-23' for future restoration
Generating a list of random MAC addresses to select from...(attempt 1 of 3)
Generated MAC addresses:
02:AB:CD:EF:12:34
02:56:78:90:AB:CD
02:DE:AD:BE:EF:12
02:34:56:78:90:AB
02:EF:CD:AB:12:34
Selected MAC address: 02:AB:CD:EF:12:34
MAC address for 'eth0' changed to: 02:AB:CD:EF:12:34
ERROR: MAC address change failed
Previous MAC: 00:11:22:33:44:55
Current MAC: 00:11:22:33:44:55
Expected MAC: 02:AB:CD:EF:12:34
```
- **Cause**: The new MAC address didn’t apply correctly (e.g., due to NIC hardware not supporting MAC address spoofing or driver ignored the change).
- **Fix**: Verify NIC hardware support for MAC spoofing. Try running the script with `sudo`.

#### Failed to Revert MAC Address (Revert)
```plaintext
Selected network interface: eth0
MAC address for 'eth0' changed to: 00:11:22:33:44:55
ERROR: Failed to revert MAC address
Current MAC: 02:AB:CD:EF:12:34
Expected MAC: 00:11:22:33:44:55
```
- **Cause**: The original MAC address didn’t apply correctly (e.g., due to NIC hardware not supporting MAC address spoofing or driver ignored the change).
- **Fix**: Verify NIC hardware support for MAC spoofing. Try running the script with `sudo`.

#### No Backup File Found (Revert)
```plaintext
Selected network interface: eth0
ERROR: No backup file found for 'eth0' in '/home/user/.config/macaddr_backup' - Cannot revert
```
- **Cause**: No `eth0_*` backup file exists in the `~/.config/macaddr_backup/` directory.
- **Fix**: Refer to the "**Revert to Original MAC Address**" bullet-point in the [How to Use](#how-to-use) section.


#### The `ip` Command Not Installed (Dependencies)
```plaintext
Spoofing MAC address...
ERROR: 'ip' is required but not installed
```
- **Cause**: The `ip` command (from `iproute2`) is missing.
- **Fix**: Install `iproute2` (e.g., `sudo apt install iproute2` on Debian/Ubuntu).

#### Invalid MAC Address Format in Backup File (Revert)
(Rare, but theoretically possible)
```plaintext
Selected network interface: eth0
ERROR: Invalid MAC address format in backup file '/home/user/.config/macaddr_backup/eth0_2025-03-23'
```
- **Cause**: The backup file contains an invalid MAC address (e.g., manually edited to `invalid`).
- **Fix**: Remove the backup file (with `sudo rm ~/.config/macaddr_backup/eth0_2025-03-23`) and recreate the backup file by running the script again.

#### MAC Address List Empty
(Rare, but theoretically possible)
```plaintext
Spoofing MAC address...
Selected network interface: eth0
Original MAC address: 00:11:22:33:44:55
Original MAC address saved to '/home/user/.config/macaddr_backup/eth0_2025-03-23' for future restoration
Generating a list of random MAC addresses to select from...(attempt 1 of 3)
Generated MAC addresses:
ERROR: MAC address list is empty
Generating a list of random MAC addresses to select from...(attempt 2 of 3)
Generated MAC addresses:
ERROR: MAC address list is empty
Generating a list of random MAC addresses to select from...(attempt 3 of 3)
Generated MAC addresses:
ERROR: MAC address list is empty
ERROR: Failed to generate a valid MAC address list after 3 attempts
```
- **Cause**: The list of generated MAC addresses was empty (e.g., due to a failure in the generation process, though unlikely with current logic unless modified).
- **Fix**: Debug the `generate_mac_list()` function output to ensure MAC addresses are being generated correctly. If you're seeing this error, you probably manually edited the script.

#### Failed to Generate Valid MAC After Max Attempts (Verification)
```plaintext
Spoofing MAC address...
Selected network interface: eth0
Original MAC address: 00:11:22:33:44:55
Original MAC address saved to '/home/user/.config/macaddr_backup/eth0_2025-03-23' for future restoration
Generating a list of random MAC addresses to select from...(attempt 1 of 3)
Generated MAC addresses:
[malformed output]
Selected MAC address: [invalid]
Invalid MAC address format detected - Retrying...
[... repeats for 3 attempts ...]
ERROR: Failed to generate valid MAC address after 3 attempts
```
- **Cause**: The generated MACs were invalid (unlikely with current `printf`, but possible if modified).
- **Fix**: Debug the `generate_mac_list()` function output to ensure MAC addresses are being generated correctly. If you're seeing this error, you probably manually edited the script.

---
## Author Details
- **Name:** James Logan Forsyth
- **Email:** james3895@duck.com
- **Date Created:** March 2025
- **License:** MIT License

      Copyright (c) 2025 - James Logan Forsyth
      
      Permission is hereby granted, free of charge, to any person obtaining a copy
      of this software and associated documentation files (the "Software"), to deal
      in the Software without restriction, including without limitation the rights
      to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
      copies of the Software, and to permit persons to whom the Software is
      furnished to do so, subject to the following conditions:

      The above copyright notice and this permission notice shall be included in all
      copies or substantial portions of the Software.

      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
      IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
      FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
      AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
      LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
      OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
      THE SOFTWARE.

---

