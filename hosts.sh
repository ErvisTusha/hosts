#!/bin/bash

#==============================================================================
# Hosts - Hosts File Management Tool
#==============================================================================
# Purpose:
#   A tool to easily manage /etc/hosts file entries with support for adding,
#   removing, and listing host entries. Features include backup creation,
#   IP validation, and command aliases.
#
# Usage:
#   ./hosts.sh [command] [arguments]
#   See --help for detailed usage information
#
# Requirements:
#   - bash shell
#   - sudo access for file modifications
#   - curl (for updates)
#
# Author:
#   Ervis Tusha <https://x.com/ET>
#   https://github.com/ErvisTusha/hosts
#
# License:
#   MIT License
#   Copyright (c) 2024 Ervis Tusha
#   See LICENSE file for details
#==============================================================================

COLOR_OFF='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'
YELLOW='\033[1;33m'

VERSION="1.0.0"
AUTHOR="Ervis Tusha"
SCRIPT=$(basename "$0")
REPO_URL="https://raw.githubusercontent.com/ErvisTusha/hosts/main/hosts.sh"

SHOW_BANNER() {
    echo '
    ██╗  ██╗ ██████╗ ███████╗████████╗███████╗
    ██║  ██║██╔═══██╗██╔════╝╚══██╔══╝██╔════╝
    ███████║██║   ██║███████╗   ██║   ███████╗
    ██╔══██║██║   ██║╚════██║   ██║   ╚════██║
    ██║  ██║╚██████╔╝███████║   ██║   ███████║
    ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚══════╝'

    echo -e "\n${GREEN}${BOLD}Hosts${NC} v${VERSION} - ${CYAN}${BOLD}Manage your hosts file${NC}"
    echo -e "${GREEN}${BOLD}GitHub${NC}: ${CYAN}${BOLD}https://github.com/ErvisTusha/hosts${NC}"
    echo -e "${GREEN}${BOLD}Author${NC}: ${RED}${BOLD}${AUTHOR}${NC}    ${GREEN}${BOLD}X${NC}: ${RED}${BOLD}https://x.com/ET${NC}"
}

SHOW_HELP() {
    echo -e "\n${BOLD}Usage:${NC}"
    echo -e "  ${CYAN}${BOLD}$SCRIPT${NC} [command] [options]"
    echo -e "\n${BOLD}Commands:${NC}"
    echo -e "  ${GREEN}${BOLD}add${NC} <ip> <domain>         | Add new host entry"
    echo -e "  ${GREEN}${BOLD}rm${NC} <ip|domain|id>         | Remove host entry"
    echo -e "  ${GREEN}${BOLD}list${NC}                      | List all entries"
    echo -e "  ${GREEN}${BOLD}search${NC} <query>            | Search for host entries"
    echo -e "  ${GREEN}${BOLD}batch${NC} <file>              | Add entries from a file"
    echo -e "  ${GREEN}${BOLD}install${NC}                   | Install script to /usr/local/bin"
    echo -e "  ${GREEN}${BOLD}update${NC}                    | Update to latest version"
    echo -e "  ${GREEN}${BOLD}uninstall${NC}                 | Remove script from system"   
    echo -e "\n${BOLD}Aliases:${NC}"    
    echo -e "  ${GREEN}${BOLD}addhost${NC} <ip> <domain>     | Add new host entry"
    echo -e "  ${GREEN}${BOLD}rmhost${NC} <ip|domain>        | Remove host entry"
    echo -e "\n${BOLD}Options:${NC}"    
    echo -e "  ${GREEN}${BOLD}-h, --help${NC}                | Show this help message"
    echo -e "  ${GREEN}${BOLD}-v, --version${NC}             | Show version information"
    echo -e "  ${GREEN}${BOLD}-l, --list${NC}                | List all entries"
    echo -e "\n${BOLD}Examples:${NC}"
    echo -e "  ${CYAN}${BOLD}$SCRIPT${NC} add 1.1.1.1 example.com"
    echo -e "  ${CYAN}${BOLD}$SCRIPT${NC} add 2001:db8::1 example.com"
    echo -e "  ${CYAN}${BOLD}$SCRIPT${NC} rm example.com"
    echo -e "  ${CYAN}${BOLD}$SCRIPT${NC} rm 1.1.1.1"
    echo -e "  ${CYAN}${BOLD}$SCRIPT${NC} rm 1"
    echo -e "  ${CYAN}${BOLD}$SCRIPT${NC} search domain"
    echo -e "  ${CYAN}${BOLD}$SCRIPT${NC} batch hosts.txt"
    echo -e "  ${CYAN}${BOLD}$SCRIPT${NC} list\n"
}

# Purpose: Validates IPv4 address format
# Parameters:
#   $1 - IP address string to validate
# Returns:
#   0 - If IP is valid
#   1 - If IP is invalid
# Notes:
#   - Currently allows IPs with leading zeros
#   - Does not validate special addresses (e.g., 0.0.0.0, 127.0.0.1)
#   - Could be enhanced with stricter validation
VALIDATE_IP() {
    local IP=$1
    
    # Check for IPv6
    if [[ $IP =~ .*:.* ]]; then
        VALIDATE_IPV6 "$IP"
        return $?
    fi
    
    # Enhanced IPv4 validation - rejects leading zeros
    if [[ $IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a SEGMENTS <<<"$IP"
        for SEGMENT in "${SEGMENTS[@]}"; do
            if [ "$SEGMENT" -gt 255 ] || [[ $SEGMENT =~ ^0[0-9]+$ ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Purpose: Validates domain name format
# Parameters:
#   $1 - Domain name to validate
# Returns:
#   0 - If domain is valid
#   1 - If domain is invalid
# Notes:
#   - Validates domain length (2-255 characters)
#   - Checks for valid characters and format
#   - Validates label length (1-63 characters)
VALIDATE_DOMAIN() {
    local DOMAIN=$1
    
    for D in $DOMAIN; do
   

        # Existing validation code
        if [ -z "$D" ] || [ ${#D} -lt 2 ] || [ ${#D} -gt 255 ]; then
            return 1
        fi

        # Enhanced regex with special character check
        if [[ ! $D =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]] || \
           [[ $D =~ [^a-zA-Z0-9.-] ]]; then
            return 1
        fi
    done
    return 0
}

VALIDATE_IPV6() {
    local IP=$1
    # Handle both full and compressed IPv6 formats, including :: notation
    if [[ $IP =~ ^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$ ]] || \
       [[ $IP =~ ^::([0-9a-fA-F]{1,4}:){0,6}[0-9a-fA-F]{1,4}$ ]] || \
       [[ $IP =~ ^([0-9a-fA-F]{1,4}:){1,7}:$ ]] || \
       [[ $IP =~ ^([0-9a-fA-F]{1,4}:){1,6}:([0-9a-fA-F]{1,4})$ ]] || \
       [[ $IP =~ ^([0-9a-fA-F]{1,4}:){1,5}(:([0-9a-fA-F]{1,4}:){1,1}[0-9a-fA-F]{1,4})$ ]] || \
       [[ $IP =~ ^([0-9a-fA-F]{1,4}:){1,4}(:([0-9a-fA-F]{1,4}:){1,2}[0-9a-fA-F]{1,4})$ ]] || \
       [[ $IP =~ ^([0-9a-fA-F]{1,4}:){1,3}(:([0-9a-fA-F]{1,4}:){1,3}[0-9a-fA-F]{1,4})$ ]] || \
       [[ $IP =~ ^([0-9a-fA-F]{1,4}:){1,2}(:([0-9a-fA-F]{1,4}:){1,4}[0-9a-fA-F]{1,4})$ ]] || \
       [[ $IP =~ ^[0-9a-fA-F]{1,4}:(:([0-9a-fA-F]{1,4}:){1,5}[0-9a-fA-F]{1,4})$ ]] || \
       [[ $IP =~ ^:((:([0-9a-fA-F]{1,4}:){1,6}[0-9a-fA-F]{1,4}))$ ]] || \
       [[ $IP =~ ^::$ ]]; then
        return 0
    fi
    return 1
}

# Purpose: Verifies sudo access for file operations
# Returns:
#   0 - If sudo access is available
#   1 - If sudo access is denied
# Notes:
#   - Exits script if sudo access is not available
CHECK_PERMISSIONS() {
    if ! sudo -v &>/dev/null; then
        echo -e "${RED}${BOLD}Error:${NC} Sudo access required for adding entry\n"
        exit 1
    fi
}

# Purpose: Creates a timestamped backup of hosts file
# Notes:
#   - Backup format: /etc/hosts.YYYYMMDD_HHMMSS.bak
#   - Exits on backup failure
BACKUP_HOSTS() {
    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    sudo cp /etc/hosts "/etc/hosts.${TIMESTAMP}.bak"
    if [ $? -ne 0 ]; then
        echo -e "\n${RED}${BOLD}Error:${NC} Failed to create backup\n"
        exit 1
    fi
}

# Purpose: Adds a new host entry to /etc/hosts
# Parameters:
#   $1 - IP address
#   $2 - Domain name
# Notes:
#   - Validates IP format
#   - Creates backup before modification
#   - Checks for duplicate entries
ADD_HOST() {
    local IP=$1
    local DOMAIN=$(echo "$2" | tr -s ' ' | xargs)  # Trim excess whitespace

    if [ -z "$DOMAIN" ]; then
        echo -e "\n${RED}${BOLD}Error:${NC} Domain cannot be empty\n"
        exit 1
    fi

    if ! VALIDATE_IP "$IP"; then
        echo -e "\n${RED}${BOLD}Error:${NC} Invalid IP address format\n"
        exit 1
    fi

    if ! VALIDATE_DOMAIN "$DOMAIN"; then
        echo -e "\n${RED}${BOLD}Error:${NC} Invalid domain name format\n"
        exit 1
    fi

    CHECK_PERMISSIONS
    BACKUP_HOSTS

    if grep -q "^$IP[[:space:]].*$DOMAIN" /etc/hosts; then
        echo -e "\n${YELLOW}${BOLD}Warning:${NC} Entry already exists $IP $DOMAIN\n"
        LIST_HOSTS
        exit 1
    fi

    if ! echo "$IP $DOMAIN" | sudo tee -a /etc/hosts >/dev/null; then
        echo -e "\n${RED}${BOLD}Error:${NC} Failed to add entry\n"
        exit 1
    fi

    echo -e "\n${GREEN}${BOLD}Success:${NC} Added $DOMAIN ($IP) to hosts file\n"
    LIST_HOSTS
    exit 0
}

# Purpose: Retrieves host entry by line number
# Parameters:
#   $1 - Line number (ID) of the entry
# Returns:
#   Host entry string or empty if not found
# Notes:
#   - Skips comments and empty lines
#   - Line numbers start from 1
GET_HOST_BY_ID() {
    local ID=$1
    local LINE_NUMBER=1
    local TARGET=""

    while read -r LINE; do
        if [ $LINE_NUMBER -eq "$ID" ]; then
            TARGET="$LINE"
            break
        fi
        ((LINE_NUMBER++))
    done < <(grep -v "^#" /etc/hosts | grep -v "^$")

    echo "$TARGET"
}

# Purpose: Removes host entry by IP, domain, or ID
# Parameters:
#   $1 - Target (IP address, domain name, or ID number)
# Notes:
#   - Creates backup before modification
#   - Can remove by exact IP match
#   - Can remove by domain name
#   - Can remove by entry ID number
REMOVE_HOST() {
    local TARGET=$1

    CHECK_PERMISSIONS
    BACKUP_HOSTS
    if [[ "$TARGET" =~ ^[0-9]+$ ]]; then
        local ENTRY=$(GET_HOST_BY_ID "$TARGET")
        if [ -z "$ENTRY" ]; then
            echo -e "\n${RED}${BOLD}Error:${NC} Invalid ID number\n"
            LIST_HOSTS
            exit 1
        fi
        local IP=$(echo "$ENTRY" | awk '{print $1}')
        local DOMAIN=$(echo "$ENTRY" | awk '{$1=""; print $0}' | xargs)

        if VALIDATE_IP "$IP"; then
            sudo sed -i "/^$IP[[:space:]]\+$DOMAIN\$/d" /etc/hosts
            echo -e "\n${GREEN}${BOLD}Success:${NC} Removed ID '$TARGET' ('$DOMAIN' with IP '$IP') entry\n"
            LIST_HOSTS
            exit 0
        else
            echo -e "\n${RED}${BOLD}Error:${NC} Invalid entry format\n"
            exit 1
        fi
    else
        if VALIDATE_IP "$TARGET"; then
            # Handle both IPv4 and IPv6 addresses
            if [[ "$TARGET" =~ .*:.* ]]; then
                # IPv6: Escape all special characters and handle compressed format
                local ESCAPED_TARGET=$(echo "$TARGET" | sed 's/[]/\[\^\$\.\*\/]/\\&/g')
                sudo sed -i "/^[[:space:]]*$ESCAPED_TARGET[[:space:]]/d" /etc/hosts
            else
                # IPv4
                sudo sed -i "/^$TARGET[[:space:]]/d" /etc/hosts
            fi
        else
            # Domain removal
            sudo sed -i "/$TARGET[[:space:]]*$/d" /etc/hosts
        fi
    fi

    if [ $? -eq 0 ]; then
        echo -e "\n${GREEN}${BOLD}Success:${NC} Removed entries matching '$TARGET'\n"
        LIST_HOSTS
        exit 0
    else
        echo -e "\n${RED}${BOLD}Error:${NC} Failed to remove entries\n"
        LIST_HOSTS
        exit 1
    fi
}

# Purpose: Lists all non-comment entries in hosts file
# Notes:
#   - Displays numbered list
#   - Skips comments and empty lines
#   - Uses color formatting for output
LIST_HOSTS() {
    echo -e "\n${CYAN}${BOLD}Current hosts entries:${NC}\n"
    local LINE_NUMBER=1
    grep -v "^#" /etc/hosts | grep -v "^$" | while read -r LINE; do
        echo -e "${YELLOW}${BOLD}$LINE_NUMBER.${NC} ${GREEN}${BOLD}→${NC} $LINE"
        ((LINE_NUMBER++))
    done
}

INSTALL_SCRIPT() {
    if ! sudo -v &>/dev/null; then
        echo -e "${RED}${BOLD}Error:${NC} Sudo access required for installation\n"
        exit 1
    fi

    echo -e "\n${CYAN}${BOLD}Installing hosts.sh...${NC}"
    if [ -f "/usr/local/bin/hosts" ]; then
        echo -e "${YELLOW}${BOLD}hosts is already installed. Use 'update' to upgrade.${NC}\n"
        exit 0
    fi

    if sudo install -m 0755 -o root -g root "$0" /usr/local/bin/hosts; then
        sudo ln -sf /usr/local/bin/hosts /usr/local/bin/addhost
        sudo ln -sf /usr/local/bin/hosts /usr/local/bin/rmhost
        echo -e "${GREEN}${BOLD}Successfully installed:${NC}"
        echo -e " - hosts to /usr/local/bin/hosts"
        echo -e " - addhost command"
        echo -e " - rmhost command"
        echo -e "\nYou can now use 'hosts', 'addhost', or 'rmhost' from anywhere\n"
    else
        echo -e "${RED}${BOLD}Failed to install hosts${NC}\n"
        exit 1
    fi
}

UPDATE_SCRIPT() {
    echo -e "\n${CYAN}${BOLD}Updating hosts.sh...${NC}"
    if [ ! -f "/usr/local/bin/hosts" ]; then
        echo -e "${YELLOW}${BOLD}hosts is not installed. Use 'install' first.${NC}\n"
        exit 1
    fi

    if ! sudo -v &>/dev/null; then
        echo -e "${RED}${BOLD}Error:${NC} Sudo access required for update\n"
        exit 1
    fi

    TEMP_FILE=$(mktemp)
    if ! command -v curl &>/dev/null; then
        echo -e "${RED}${BOLD}Error:${NC} curl command not found. Please install curl package\n"
        exit 1
    fi

    if curl -sL "$REPO_URL" -o "$TEMP_FILE"; then
        if sudo cp "$TEMP_FILE" /usr/local/bin/hosts && sudo chmod +x /usr/local/bin/hosts; then
            rm "$TEMP_FILE"
            echo -e "${GREEN}${BOLD}Successfully updated hosts${NC}\n"
        else
            rm "$TEMP_FILE"
            echo -e "${RED}${BOLD}Failed to update hosts${NC}\n"
            exit 1
        fi
    else
        rm "$TEMP_FILE"
        echo -e "${RED}${BOLD}Failed to download update${NC}\n"
        exit 1
    fi
}

UNINSTALL_SCRIPT() {
    echo -e "\n${CYAN}${BOLD}Uninstalling hosts.sh...${NC}"
    if [ ! -f "/usr/local/bin/hosts" ]; then
        echo -e "${YELLOW}${BOLD}hosts is not installed${NC}\n"
        exit 0
    fi

    if ! sudo -v &>/dev/null; then
        echo -e "${RED}${BOLD}Error:${NC} Sudo access required for uninstallation\n"
        exit 1
    fi

    sudo rm -f /usr/local/bin/hosts
    sudo rm -f /usr/local/bin/addhost
    sudo rm -f /usr/local/bin/rmhost
    echo -e "${GREEN}${BOLD}Successfully uninstalled all commands${NC}\n"
}

# Add search functionality
SEARCH_HOSTS() {
    local QUERY=$1
    echo -e "\n${CYAN}${BOLD}Searching for entries matching '$QUERY':${NC}\n"
    grep -i "$QUERY" /etc/hosts | grep -v "^#" | while read -r LINE; do
        echo -e "${GREEN}${BOLD}→${NC} $LINE"
    done
}

# Add batch operation function
BATCH_ADD_HOSTS() {
    local FILE=$1
    local SUCCESS=0
    local FAILED=0

    if [ ! -f "$FILE" ]; then
        echo -e "\n${RED}${BOLD}Error:${NC} File not found: $FILE\n"
        exit 1  # Changed from return 1 to exit 1 to ensure proper error propagation
    fi

    while IFS= read -r LINE || [ -n "$LINE" ]; do
        # Skip comments and empty lines
        [[ $LINE =~ ^[[:space:]]*# ]] && continue
        [[ -z $LINE ]] && continue

        local IP=$(echo "$LINE" | awk '{print $1}')
        local DOMAIN=$(echo "$LINE" | awk '{$1=""; print $0}' | xargs)

        if ADD_HOST "$IP" "$DOMAIN" >/dev/null 2>&1; then
            ((SUCCESS++))
        else
            ((FAILED++))
            echo -e "${RED}${BOLD}Failed:${NC} $IP $DOMAIN"
        fi
    done < "$FILE"

    echo -e "\n${GREEN}${BOLD}Batch operation completed:${NC}"
    echo -e "Success: $SUCCESS"
    echo -e "Failed: $FAILED\n"
}

SHOW_BANNER

case "$SCRIPT" in
"$SCRIPT" | "addhost" | "rmhost")
    case "$1" in
    -h | --help)
        SHOW_HELP
        exit 0
        ;;
    -v | --version)
        SHOW_BANNER
        exit 0
        ;;
    add)
        ADD_HOST "$2" "$3"
        ;;
    rm)
        REMOVE_HOST "$2"
        ;;
    install | update | uninstall)
        CMD=$(echo "$1" | tr '[:lower:]' '[:upper:]')
        "${CMD}_SCRIPT"
        SHOW_HELP
        ;;
    -l | --list | list)
        LIST_HOSTS
        ;;
    search)
        SEARCH_HOSTS "$2"
        ;;
    batch)
        BATCH_ADD_HOSTS "$2"
        ;;
    *)
        if [ "$SCRIPT" = "addhost" ]; then
            [ -z "$1" ] && {
                SHOW_HELP
                exit 1
            }
            ADD_HOST "$1" "$2"
        elif [ "$SCRIPT" = "rmhost" ]; then
            [ -z "$1" ] && {
                LIST_HOSTS
                exit 1
            }
            REMOVE_HOST "$1"
            exit 1
        else
            SHOW_HELP
            exit 1
        fi
        ;;
    esac
    ;;
*)
    echo -e "${RED}${BOLD}Error:${NC} Invalid command\n"
    SHOW_HELP
    exit 1
    ;;
esac
exit 0
