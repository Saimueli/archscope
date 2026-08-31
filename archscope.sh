#!/usr/bin/env bash

# ==============================================================================
# Arch Linux Application & System Analyzer
# Target OS: Arch-based distributions
# ==============================================================================

# Text Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper Functions
pause() {
    echo ""
    echo -e "${YELLOW}Press [Enter] to return to the main menu...${NC}"
    read -r
}

print_header() {
    clear
    echo -e "${CYAN}==============================================================================${NC}"
    echo -e "${BOLD}${GREEN}                   ARCH LINUX APP & SYSTEM ANALYZER                           ${NC}"
    echo -e "${CYAN}==============================================================================${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# 1. System Information
# ------------------------------------------------------------------------------
show_sys_info() {
    print_header
    echo -e "${BOLD}${BLUE}--- [1] SYSTEM INFORMATION ---${NC}\n"

    # OS Info
    if [ -f /etc/os-release ]; then
        OS_NAME=$(grep -E '^PRETTY_NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
    else
        OS_NAME=$(uname -s)
    fi

    KERNEL=$(uname -r)
    ARCH=$(uname -m)
    UPTIME=$(uptime -p | sed 's/up //')
    HOSTNAME=$(hostname)
    USER_SHELL=$(basename "$SHELL")
    DE_WM=${XDG_CURRENT_DESKTOP:-$DESKTOP_SESSION}
    DE_WM=${DE_WM:-"CLI/Unknown"}
    SESSION_TYPE=${XDG_SESSION_TYPE:-"Unknown"}

    # Hardware Info
    CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | awk -F: '{print $2}' | xargs)
    CORES=$(nproc)

    # GPU Info (Handles multiple GPUs natively)
    if command -v lspci &>/dev/null; then
        GPU_MODEL=$(lspci | grep -iE 'VGA|3D' | awk -F': ' '{print $2}' | paste -sd " / " -)
    else
        GPU_MODEL="lspci command not found"
    fi
    [ -z "$GPU_MODEL" ] && GPU_MODEL="Unknown"

    echo -e "${BOLD}SOFTWARE & OS:${NC}"
    echo -e "  ${BOLD}OS:${NC}                 $OS_NAME ($ARCH)"
    echo -e "  ${BOLD}Kernel:${NC}             $KERNEL"
    echo -e "  ${BOLD}Hostname:${NC}           $HOSTNAME"
    echo -e "  ${BOLD}Uptime:${NC}             $UPTIME"
    echo -e "  ${BOLD}Desktop Env/WM:${NC}     $DE_WM ($SESSION_TYPE)"
    echo -e "  ${BOLD}Shell:${NC}              $USER_SHELL"
    echo ""

    echo -e "${BOLD}HARDWARE:${NC}"
    echo -e "  ${BOLD}CPU:${NC}                $CPU_MODEL ($CORES threads)"
    echo -e "  ${BOLD}GPU:${NC}                $GPU_MODEL"
    echo ""

    # Memory Info (Includes RAM and Swap)
    echo -e "${BOLD}MEMORY:${NC}"
    free -h | awk '
        NR==1{printf "  %-12s %-10s %-10s %-10s %-10s\n", "", $2, $3, $4, $7}
        NR==2{printf "  %-12s %-10s %-10s %-10s %-10s\n", "Physical:", $2, $3, $4, $7}
        NR==3{printf "  %-12s %-10s %-10s %-10s %-10s\n", "Swap:", $2, $3, $4, "N/A"}'
    echo ""

    # Root Disk Info
    echo -e "${BOLD}STORAGE (/):${NC}"
    df -h / | awk '
        NR==1{printf "  %-12s %-10s %-10s %-10s %-10s\n", "Mount", $2, $3, $4, $5}
        NR==2{printf "  %-12s %-10s %-10s %-10s %-10s\n", $6, $2, $3, $4, $5}'
    echo ""

    # Package counts
    PACMAN_COUNT=$(pacman -Q 2>/dev/null | wc -l)
    FLATPAK_COUNT=$(command -v flatpak &>/dev/null && flatpak list --app 2>/dev/null | wc -l || echo "0 (Not installed)")

    echo -e "${BOLD}PACKAGE COUNTS:${NC}"
    echo -e "  ${BOLD}Pacman:${NC}             $PACMAN_COUNT"
    echo -e "  ${BOLD}Flatpak:${NC}            $FLATPAK_COUNT"

    pause
}

# ------------------------------------------------------------------------------
# 2. All Pacman Packages (Filtered by Size or Alphabetically)
# ------------------------------------------------------------------------------
show_pacman_packages() {
    print_header
    echo -e "${BOLD}${BLUE}--- [2] PACMAN PACKAGES ---${NC}\n"
    echo "1. List Alphabetically (Name, Size, Binary Location)"
    echo "2. List Sorted by Size (Largest to Smallest)"
    echo -n "Choose an option [1-2]: "
    read -r p_choice

    print_header

    # Function to parse pacman package metadata
    get_pacman_data() {
        echo -e "${YELLOW}Gathering pacman package info... Please wait standard loading time...${NC}\n"

        # Parse pacman -Qi correctly grabbing $4 (number) and $5 (unit) since $3 is the colon (:)
        pacman -Qi | awk '
        /^Name/ { name=$3 }
        /^Installed Size/ {
            val=$4; unit=$5;
            bytes=val;
            if (unit == "B") bytes=val;
            else if (unit == "KiB") bytes=val*1024;
            else if (unit == "MiB") bytes=val*1024*1024;
            else if (unit == "GiB") bytes=val*1024*1024*1024;

            # Print as exact integer to prevent scientific notation breaking numerical sort
            printf "%.0f\t%s\t%s %s\n", bytes, name, val, unit;
        }'
    }

    if [ "$p_choice" == "1" ]; then
        echo -e "${BOLD}Pacman Packages (Alphabetical):${NC}\n"
        printf "%-35s %-15s %-30s\n" "PACKAGE NAME" "SIZE" "PRIMARY BINARY LOCATION"
        echo "----------------------------------------------------------------------------------"

        get_pacman_data | sort -k2,2 | while IFS=$'\t' read -r bytes name size_str; do
            bin_path=$(which "$name" 2>/dev/null || echo "/usr/lib/$name (or shared libs)")
            printf "%-35s %-15s %-30s\n" "$name" "$size_str" "$bin_path"
        done | less -R -P"--- Press 'q' to quit and return to menu, arrows to scroll ---"
        pause

    elif [ "$p_choice" == "2" ]; then
        echo -e "${BOLD}Pacman Packages (Largest to Smallest):${NC}\n"
        printf "%-35s %-15s %-30s\n" "PACKAGE NAME" "SIZE" "PRIMARY BINARY LOCATION"
        echo "----------------------------------------------------------------------------------"

        get_pacman_data | sort -rn -k1,1 | while IFS=$'\t' read -r bytes name size_str; do
            bin_path=$(which "$name" 2>/dev/null || echo "N/A or Shared Library")
            printf "%-35s %-15s %-30s\n" "$name" "$size_str" "$bin_path"
        done | less -R -P"--- Press 'q' to quit and return to menu, arrows to scroll ---"
        pause
    else
        echo -e "${RED}Invalid selection.${NC}"
        pause
    fi
}

# ------------------------------------------------------------------------------
# 3. Flatpak Applications
# ------------------------------------------------------------------------------
show_flatpaks() {
    print_header
    echo -e "${BOLD}${BLUE}--- [3] FLATPAK APPLICATIONS ---${NC}\n"

    if ! command -v flatpak &>/dev/null; then
        echo -e "${RED}Flatpak is not installed on this system.${NC}"
        pause
        return
    fi

    FLATPAK_LIST=$(flatpak list --app --columns=name,application,size,installation 2>/dev/null)

    if [ -z "$FLATPAK_LIST" ]; then
        echo "No Flatpak applications found."
        pause
    else
        printf "%-30s %-35s %-12s %-20s\n" "NAME" "APPLICATION ID" "SIZE" "INSTALL PATH"
        echo "--------------------------------------------------------------------------------------------------------"

        flatpak list --app --columns=name,application,size,installation | while read -r line; do
            # Extract basic flatpak details
            name=$(echo "$line" | awk -F'\t' '{print $1}')
            appid=$(echo "$line" | awk -F'\t' '{print $2}')
            size=$(echo "$line" | awk -F'\t' '{print $3}')
            inst_type=$(echo "$line" | awk -F'\t' '{print $4}')

            if [ "$inst_type" == "system" ]; then
                location="/var/lib/flatpak/app/$appid"
            else
                location="$HOME/.local/share/flatpak/app/$appid"
            fi

            printf "%-30s %-35s %-12s %-20s\n" "${name:0:28}" "${appid:0:33}" "$size" "$location"
        done | less -R -P"--- Press 'q' to quit and return to menu, arrows to scroll ---"
        pause
    fi
}

# ------------------------------------------------------------------------------
# 4. AppImage Applications
# ------------------------------------------------------------------------------
show_appimages() {
    print_header
    echo -e "${BOLD}${BLUE}--- [4] APPIMAGE APPLICATIONS ---${NC}\n"
    echo -e "${YELLOW}Scanning typical directories (~/, /opt, /usr/local, Downloads, Applications) for .AppImage files...${NC}\n"

    SEARCH_DIRS=("$HOME" "/opt" "/usr/local/bin")

    printf "%-35s %-12s %-50s\n" "APPIMAGE NAME" "SIZE" "EXACT LOCATION"
    echo "---------------------------------------------------------------------------------------------------"

    found=0
    for dir in "${SEARCH_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r file; do
                if [ -n "$file" ]; then
                    found=1
                    filename=$(basename "$file")
                    size=$(du -h "$file" | awk '{print $1}')
                    printf "%-35s %-12s %-50s\n" "${filename:0:33}" "$size" "$file"
                fi
            done < <(find "$dir" -maxdepth 4 -type f \( -iname "*.appimage" -o -iname "*.app" \) 2>/dev/null)
        fi
    done

    if [ $found -eq 0 ]; then
        echo "No AppImage files found in common search paths."
    fi

    pause
}

# ------------------------------------------------------------------------------
# 5. Unused or Rarely Used Applications
# ------------------------------------------------------------------------------
show_unused_apps() {
    print_header
    echo -e "${BOLD}${BLUE}--- [5] UNUSED OR RARELY USED APPLICATIONS ---${NC}\n"
    echo -e "${YELLOW}Analyzing access times (atime/mtime) for desktop applications...${NC}"
    echo -e "${RED}Note: If your filesystem uses 'noatime', access dates reflect installation/modification date.${NC}\n"

    printf "%-30s %-12s %-20s %-35s\n" "APPLICATION NAME" "SIZE" "LAST ACCESSED" "EXACT LOCATION"
    echo "-------------------------------------------------------------------------------------------------------------------"

    # Scan .desktop files in standard desktop entries
    DESKTOP_FILES=$(ls /usr/share/applications/*.desktop $HOME/.local/share/applications/*.desktop 2>/dev/null)

    (
    for dfile in $DESKTOP_FILES; do
        # Extract binary executable from Exec line
        exec_cmd=$(grep -E '^Exec=' "$dfile" | head -n 1 | cut -d'=' -f2 | awk '{print $1}' | tr -d '"')
        app_name=$(grep -E '^Name=' "$dfile" | head -n 1 | cut -d'=' -f2)

        if [ -n "$exec_cmd" ]; then
            bin_path=$(which "$exec_cmd" 2>/dev/null)

            if [ -n "$bin_path" ] && [ -f "$bin_path" ]; then
                # Get last access date and size
                last_access=$(stat -c "%x" "$bin_path" 2>/dev/null | cut -d' ' -f1)
                size=$(du -h "$bin_path" 2>/dev/null | awk '{print $1}')

                # Sortable timestamp epoch
                epoch=$(stat -c "%X" "$bin_path" 2>/dev/null || echo "0")

                echo -e "$epoch\t${app_name:-$exec_cmd}\t$size\t$last_access\t$bin_path"
            fi
        fi
    done
    ) | sort -n -k1,1 | awk -F'\t' '{printf "%-30s %-12s %-20s %-35s\n", substr($2,1,28), $3, $4, $5}' | less -R -P"--- Press 'q' to quit and return to menu, arrows to scroll ---"

    pause
}

# ------------------------------------------------------------------------------
# 6. Current RAM Usage per Application
# ------------------------------------------------------------------------------
show_ram_usage() {
    print_header
    echo -e "${BOLD}${BLUE}--- [6] CURRENT RAM USAGE PER APPLICATION ---${NC}\n"
    echo -e "${YELLOW}Aggregating active process RAM consumption...${NC}\n"

    printf "%-35s %-15s %-15s %-15s\n" "PROCESS / APP NAME" "TOTAL RAM (MB)" "RAM SHARE (%)" "PROCESS COUNT"
    echo "------------------------------------------------------------------------------------"

    # Uses ps to group memory usage (RSS in KB) per command base name
    ps -eo comm,rss,%mem --no-headers | awk '
    {
        mem[$1] += $2;
        pmem[$1] += $3;
        count[$1] += 1;
    }
    END {
        for (proc in mem) {
            # Convert KB to MB
            mb = mem[proc] / 1024;
            printf "%-35s %-15.2f %-15.2f %-15d\n", proc, mb, pmem[proc], count[proc];
        }
    }' | sort -k2 -nr | head -n 30 | less -R -P"--- Press 'q' to quit and return to menu, arrows to scroll ---"

    pause
}

# ------------------------------------------------------------------------------
# 7. Boot Time & Slowing Components
# ------------------------------------------------------------------------------
show_boot_time() {
    print_header
    echo -e "${BOLD}${BLUE}--- [7] BOOT TIME ANALYSIS & BLAME ---${NC}\n"

    if ! command -v systemd-analyze &>/dev/null; then
        echo -e "${RED}systemd-analyze is not available on this system.${NC}"
        pause
        return
    fi

    echo -e "${BOLD}Overall Boot Time Breakdown:${NC}"
    echo "----------------------------------------------------------------------------------"
    systemd-analyze
    echo ""

    echo -e "${BOLD}Top 15 Services Slowing Down Boot Time (Exact Names & Duration):${NC}"
    echo "----------------------------------------------------------------------------------"
    systemd-analyze blame | head -n 15
    echo ""

    echo -e "${BOLD}Critical Chain Bottleneck:${NC}"
    echo "----------------------------------------------------------------------------------"
    systemd-analyze critical-chain | head -n 15

    pause
}

# ------------------------------------------------------------------------------
# Main Menu Loop
# ------------------------------------------------------------------------------
main_menu() {
    while true; do
        print_header
        echo -e "${BOLD}Select an option from the menu:${NC}\n"
        echo -e "  ${GREEN}1.${NC} System Information"
        echo -e "  ${GREEN}2.${NC} All Pacman Packages (Sort by Size / Alphabetically)"
        echo -e "  ${GREEN}3.${NC} Flatpak Applications"
        echo -e "  ${GREEN}4.${NC} AppImage Applications"
        echo -e "  ${GREEN}5.${NC} Unused / Rarely Used Applications"
        echo -e "  ${GREEN}6.${NC} Current RAM Usage per Application"
        echo -e "  ${GREEN}7.${NC} Boot Time Analysis & Slow Services"
        echo -e "  ${RED}0. Exit${NC}"
        echo ""
        echo -n "Enter choice [0-7]: "
        read -r choice

        case $choice in
            1) show_sys_info ;;
            2) show_pacman_packages ;;
            3) show_flatpaks ;;
            4) show_appimages ;;
            5) show_unused_apps ;;
            6) show_ram_usage ;;
            7) show_boot_time ;;
            0)
                echo -e "\n${GREEN}Exiting. Have a great day!${NC}"
                exit 0
                ;;
            *)
                echo -e "\n${RED}Invalid option! Please enter a number between 0 and 7.${NC}"
                sleep 1.5
                ;;
        esac
    done
}

# Start script
main_menu
