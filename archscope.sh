#!/usr/bin/env bash

# ==============================================================================
# ArchScope v1.1 - Arch Linux Application & System Analyzer
# Target OS: Arch-based distributions
# ==============================================================================

# Vibrant ANSI Color Palette
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Helper Functions
pause() {
    echo ""
    echo -e "${YELLOW}➜ Press [Enter] to return to the main menu...${NC}"
    read -r
}

print_header() {
    clear
    echo -e "${MAGENTA}┌──────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${MAGENTA}│${NC}   ${CYAN}${BOLD}    ARCHSCOPE ${WHITE}v1.1${CYAN} - Arch Application & System Analyzer   ${NC}   ${MAGENTA}              │${NC}"
    echo -e "${MAGENTA}└──────────────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# ------------------------------------------------------------------------------
# 1. System Information
# ------------------------------------------------------------------------------
show_sys_info() {
    print_header
    echo -e "${BOLD}${CYAN}──────────────────────── [1] SYSTEM INFORMATION ────────────────────────${NC}\n"

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

    if command -v lspci &>/dev/null; then
        GPU_MODEL=$(lspci | grep -iE 'VGA|3D' | awk -F': ' '{print $2}' | paste -sd " / " -)
    else
        GPU_MODEL="lspci command not found"
    fi
    [ -z "$GPU_MODEL" ] && GPU_MODEL="Unknown"

    echo -e " ${BOLD}${YELLOW}🖥  SOFTWARE & OS${NC}"
    echo -e "  ${BOLD}OS:${NC}                 $OS_NAME ($ARCH)"
    echo -e "  ${BOLD}Kernel:${NC}             $KERNEL"
    echo -e "  ${BOLD}Hostname:${NC}           $HOSTNAME"
    echo -e "  ${BOLD}Uptime:${NC}             $UPTIME"
    echo -e "  ${BOLD}Desktop/WM:${NC}         $DE_WM ($SESSION_TYPE)"
    echo -e "  ${BOLD}Shell:${NC}              $USER_SHELL"
    echo ""

    echo -e " ${BOLD}${GREEN}⚡ HARDWARE${NC}"
    echo -e "  ${BOLD}CPU:${NC}                $CPU_MODEL ($CORES threads)"
    echo -e "  ${BOLD}GPU:${NC}                $GPU_MODEL"
    echo ""

    echo -e " ${BOLD}${MAGENTA}🧠 MEMORY${NC}"
    free -h | awk '
        NR==1{printf "  \033[1m%-12s %-10s %-10s %-10s %-10s\033[0m\n", "", $2, $3, $4, $7}
        NR==2{printf "  %-12s %-10s %-10s %-10s %-10s\n", "Physical:", $2, $3, $4, $7}
        NR==3{printf "  %-12s %-10s %-10s %-10s %-10s\n", "Swap:", $2, $3, $4, "N/A"}'
    echo ""

    echo -e " ${BOLD}${CYAN}💾 STORAGE (/)${NC}"
    df -h / | awk '
        NR==1{printf "  \033[1m%-12s %-10s %-10s %-10s %-10s\033[0m\n", "Mount", $2, $3, $4, $5}
        NR==2{printf "  %-12s %-10s %-10s %-10s %-10s\n", $6, $2, $3, $4, $5}'
    echo ""

    PACMAN_COUNT=$(pacman -Q 2>/dev/null | wc -l)
    FLATPAK_COUNT=$(command -v flatpak &>/dev/null && flatpak list --app 2>/dev/null | wc -l || echo "0 (Not installed)")

    echo -e " ${BOLD}${BLUE}📦 PACKAGE COUNTS${NC}"
    echo -e "  ${BOLD}Pacman Packages:${NC}   $PACMAN_COUNT"
    echo -e "  ${BOLD}Flatpak Apps:${NC}      $FLATPAK_COUNT"

    pause
}

# ------------------------------------------------------------------------------
# 2. All Pacman Packages (Improved Exact Units & Formatting)
# ------------------------------------------------------------------------------
show_pacman_packages() {
    print_header
    echo -e "${BOLD}${CYAN}──────────────────────── [2] PACMAN PACKAGES ────────────────────────${NC}\n"
    echo -e "  ${GREEN}1.${NC} List Alphabetically (A-Z)"
    echo -e "  ${GREEN}2.${NC} List Sorted by Size (Largest to Smallest)"
    echo ""
    echo -n "Choose an option [1-2]: "
    read -r p_choice

    print_header

    get_pacman_data() {
        echo -e "${YELLOW}Analyzing package sizes... Please wait standard loading time...${NC}\n"

        # Parses pacman -Qi and explicitly extracts exact numbers and units (B, KiB, MiB, GiB)
        pacman -Qi | awk '
        /^Name/ { name=$3 }
        /^Installed Size/ {
            val=$4; unit=$5;
            bytes=val;
            if (unit == "B") bytes=val;
            else if (unit == "KiB") bytes=val*1024;
            else if (unit == "MiB") bytes=val*1024*1024;
            else if (unit == "GiB") bytes=val*1024*1024*1024;

            # Formats unit explicitly to 2 decimal places with unit label
            formatted_size = sprintf("%.2f %s", val, unit);
            printf "%.0f\t%s\t%s\n", bytes, name, formatted_size;
        }'
    }

    PAGER_PROMPT="--- Press 'q' to quit and return to menu, arrows/PageUp/PageDown to scroll ---"

    if [ "$p_choice" == "1" ]; then
        echo -e "${BOLD}${GREEN}Pacman Packages (Alphabetical Order):${NC}\n"
        printf "${BOLD}${MAGENTA}%-35s %-16s %-30s${NC}\n" "PACKAGE NAME" "EXACT SIZE" "PRIMARY BINARY LOCATION"
        echo -e "${BLUE}──────────────────────────────────────────────────────────────────────────────────────────${NC}"

        get_pacman_data | sort -k2,2 | while IFS=$'\t' read -r bytes name size_str; do
            bin_path=$(which "$name" 2>/dev/null || echo "/usr/lib/$name (or shared libs)")
            printf "%-35s \033[1;33m%-16s\033[0m %-30s\n" "$name" "$size_str" "$bin_path"
        done | less -R -P"$PAGER_PROMPT"
        pause

    elif [ "$p_choice" == "2" ]; then
        echo -e "${BOLD}${GREEN}Pacman Packages (Sorted: Largest to Smallest):${NC}\n"
        printf "${BOLD}${MAGENTA}%-35s %-16s %-30s${NC}\n" "PACKAGE NAME" "EXACT SIZE" "PRIMARY BINARY LOCATION"
        echo -e "${BLUE}──────────────────────────────────────────────────────────────────────────────────────────${NC}"

        get_pacman_data | sort -rn -k1,1 | while IFS=$'\t' read -r bytes name size_str; do
            bin_path=$(which "$name" 2>/dev/null || echo "N/A or Shared Library")
            printf "%-35s \033[1;33m%-16s\033[0m %-30s\n" "$name" "$size_str" "$bin_path"
        done | less -R -P"$PAGER_PROMPT"
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
    echo -e "${BOLD}${CYAN}──────────────────────── [3] FLATPAK APPLICATIONS ────────────────────────${NC}\n"

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
        printf "${BOLD}${MAGENTA}%-28s %-32s %-14s %-20s${NC}\n" "NAME" "APPLICATION ID" "EXACT SIZE" "INSTALL PATH"
        echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────────────────────────────${NC}"

        flatpak list --app --columns=name,application,size,installation | while read -r line; do
            name=$(echo "$line" | awk -F'\t' '{print $1}')
            appid=$(echo "$line" | awk -F'\t' '{print $2}')
            size=$(echo "$line" | awk -F'\t' '{print $3}')
            inst_type=$(echo "$line" | awk -F'\t' '{print $4}')

            if [ "$inst_type" == "system" ]; then
                location="/var/lib/flatpak/app/$appid"
            else
                location="$HOME/.local/share/flatpak/app/$appid"
            fi

            printf "%-28s %-32s \033[1;33m%-14s\033[0m %-20s\n" "${name:0:26}" "${appid:0:30}" "$size" "$location"
        done | less -R -P"--- Press 'q' to quit and return to menu, arrows to scroll ---"
        pause
    fi
}

# ------------------------------------------------------------------------------
# 4. AppImage Applications
# ------------------------------------------------------------------------------
show_appimages() {
    print_header
    echo -e "${BOLD}${CYAN}──────────────────────── [4] APPIMAGE APPLICATIONS ────────────────────────${NC}\n"
    echo -e "${YELLOW}Scanning system directories (~/, /opt, /usr/local, Downloads) for AppImages...${NC}\n"

    SEARCH_DIRS=("$HOME" "/opt" "/usr/local/bin")

    printf "${BOLD}${MAGENTA}%-32s %-14s %-50s${NC}\n" "APPIMAGE NAME" "EXACT SIZE" "EXACT LOCATION"
    echo -e "${BLUE}───────────────────────────────────────────────────────────────────────────────────────────────────${NC}"

    found=0
    for dir in "${SEARCH_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r file; do
                if [ -n "$file" ]; then
                    found=1
                    filename=$(basename "$file")
                    size=$(du -h "$file" | awk '{print $1}')
                    printf "%-32s \033[1;33m%-14s\033[0m %-50s\n" "${filename:0:30}" "$size" "$file"
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
    echo -e "${BOLD}${CYAN}────────────────── [5] UNUSED / RARELY USED APPLICATIONS ──────────────────${NC}\n"
    echo -e "${YELLOW}Analyzing access/modification timestamps for launcher executables...${NC}"
    echo -e "${DIM}Note: Filesystems mounted with 'noatime' show installation/modification dates.${NC}\n"

    printf "${BOLD}${MAGENTA}%-28s %-12s %-20s %-35s${NC}\n" "APPLICATION NAME" "EXACT SIZE" "LAST ACCESSED" "EXACT LOCATION"
    echo -e "${BLUE}───────────────────────────────────────────────────────────────────────────────────────────────────────────────────${NC}"

    DESKTOP_FILES=$(ls /usr/share/applications/*.desktop $HOME/.local/share/applications/*.desktop 2>/dev/null)

    (
    for dfile in $DESKTOP_FILES; do
        exec_cmd=$(grep -E '^Exec=' "$dfile" | head -n 1 | cut -d'=' -f2 | awk '{print $1}' | tr -d '"')
        app_name=$(grep -E '^Name=' "$dfile" | head -n 1 | cut -d'=' -f2)

        if [ -n "$exec_cmd" ]; then
            bin_path=$(which "$exec_cmd" 2>/dev/null)

            if [ -n "$bin_path" ] && [ -f "$bin_path" ]; then
                last_access=$(stat -c "%x" "$bin_path" 2>/dev/null | cut -d' ' -f1)
                size=$(du -h "$bin_path" 2>/dev/null | awk '{print $1}')
                epoch=$(stat -c "%X" "$bin_path" 2>/dev/null || echo "0")

                echo -e "$epoch\t${app_name:-$exec_cmd}\t$size\t$last_access\t$bin_path"
            fi
        fi
    done
    ) | sort -n -k1,1 | awk -F'\t' '{printf "%-28s \033[1;33m%-12s\033[0m %-20s %-35s\n", substr($2,1,26), $3, $4, $5}' | less -R -P"--- Press 'q' to quit and return to menu, arrows to scroll ---"

    pause
}

# ------------------------------------------------------------------------------
# 6. Current RAM Usage per Application (Redesigned & Visual)
# ------------------------------------------------------------------------------
show_ram_usage() {
    print_header
    echo -e "${BOLD}${CYAN}─────────────────── [6] CURRENT RAM USAGE PER APPLICATION ───────────────────${NC}\n"
    echo -e "${YELLOW}Aggregating real-time memory usage per process group...${NC}\n"

    printf "${BOLD}${MAGENTA}%-28s %-14s %-16s %-12s %-8s${NC}\n" "PROCESS / APP NAME" "MEMORY USAGE" "RAM SHARE (%)" "USAGE BAR" "COUNT"
    echo -e "${BLUE}────────────────────────────────────────────────────────────────────────────────────────────${NC}"

    # Aggregates RSS memory, converts to dynamic MB/GB, and builds a visual meter bar
    ps -eo comm,rss,%mem --no-headers | awk '
    {
        mem[$1] += $2; # RSS in KB
        pmem[$1] += $3;
        count[$1] += 1;
    }
    END {
        for (proc in mem) {
            kb = mem[proc];
            mb = kb / 1024;

            if (mb >= 1024) {
                ram_str = sprintf("%.2f GB", mb / 1024);
            } else {
                ram_str = sprintf("%.2f MB", mb);
            }

            pct = pmem[proc];
            bars = int(pct / 2);
            if (bars > 10) bars = 10;

            bar_str = "";
            for (i=1; i<=bars; i++) bar_str = bar_str "█";
            for (i=bars+1; i<=10; i++) bar_str = bar_str "░";

            printf "%.0f\t%s\t%s\t%.2f\t%s\t%d\n", kb, proc, ram_str, pct, bar_str, count[proc];
        }
    }' | sort -rn -k1,1 | head -n 40 | awk -F'\t' '{
        printf "%-28s \033[1;33m%-14s\033[0m %-6.2f%%          \033[1;36m%-12s\033[0m \033[1m%-8d\033[0m\n", substr($2,1,26), $3, $4, $5, $6;
    }' | less -R -P"--- Press 'q' to quit and return to menu, arrows to scroll ---"

    pause
}

# ------------------------------------------------------------------------------
# 7. Boot Time & Slowing Components
# ------------------------------------------------------------------------------
show_boot_time() {
    print_header
    echo -e "${BOLD}${CYAN}────────────────── [7] BOOT TIME ANALYSIS & BOTTLENECKS ──────────────────${NC}\n"

    if ! command -v systemd-analyze &>/dev/null; then
        echo -e "${RED}systemd-analyze is not available on this system.${NC}"
        pause
        return
    fi

    echo -e "${BOLD}${YELLOW}⏱ Overall Boot Time Breakdown:${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────────────────────────────${NC}"
    systemd-analyze
    echo ""

    echo -e "${BOLD}${YELLOW}🐢 Top 15 Services Slowing Down Startup (systemd blame):${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────────────────────────────${NC}"
    systemd-analyze blame | head -n 15
    echo ""

    echo -e "${BOLD}${YELLOW}🔍 Critical Chain Bottleneck:${NC}"
    echo -e "${BLUE}──────────────────────────────────────────────────────────────────────────────────────────${NC}"
    systemd-analyze critical-chain | head -n 15

    pause
}

# ------------------------------------------------------------------------------
# Main Menu Loop
# ------------------------------------------------------------------------------
main_menu() {
    while true; do
        print_header
        echo -e "${BOLD}${WHITE}  Select an option from the menu:${NC}\n"
        echo -e "  ${GREEN}1.${NC} 💻 System Information"
        echo -e "  ${GREEN}2.${NC} 📦 Pacman Packages (Exact Sizes & Formats)"
        echo -e "  ${GREEN}3.${NC} 🔷 Flatpak Applications"
        echo -e "  ${GREEN}4.${NC} 💎 AppImage Applications"
        echo -e "  ${GREEN}5.${NC} 🧹 Unused / Rarely Used Applications"
        echo -e "  ${GREEN}6.${NC} 🧠 Current RAM Usage (Visual Meter & Exact Sizes)"
        echo -e "  ${GREEN}7.${NC} 🚀 Boot Time Analysis & Startup Bottlenecks"
        echo -e "  ${RED}0. 🚪 Exit${NC}"
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
                echo -e "\n${GREEN}Exiting ArchScope. Have a great day!${NC}"
                exit 0
                ;;
            *)
                echo -e "\n${RED}Invalid option! Please enter a number between 0 and 7.${NC}"
                sleep 1.2
                ;;
        esac
    done
}

# Start script
main_menu
