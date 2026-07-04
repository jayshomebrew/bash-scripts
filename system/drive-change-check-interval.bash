#!/usr/bin/env bash

set -euo pipefail

GREEN="\e[1;92m"
YELLOW="\e[1;33m"
RED="\e[1;31m"
EC="\e[0m"

confirm() {
    while true; do
        read -rp "$(echo -e "$1 [${YELLOW}Y${EC}/n]: ")" ans

        case "${ans:-Y}" in
            Y|y|"")
                return 0
                ;;
            N|n)
                echo -e "${RED}Aborted.${EC}"
                exit 0
                ;;
            *)
                echo "Please answer Y or n."
                ;;
        esac
    done
}

echo
echo
echo "This script will search for your root drive"
echo "then change the check interval to every 30 days"
echo
echo
echo "Searching for the root filesystem..."

ROOT_DEV=$(findmnt -n -o SOURCE /)

if [[ -z "$ROOT_DEV" ]]; then
    echo "Unable to determine the root filesystem. Exiting"
    exit 1
fi

echo
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT "$ROOT_DEV"
echo
df -h /
echo
echo -e "Root filesystem is mounted from:"
echo -e "${GREEN}${ROOT_DEV}${EC}"
echo 
confirm "Continue using this device?"

echo
echo "Current filesystem check settings:"
sudo tune2fs -l "$ROOT_DEV" | grep -E "Filesystem state|Check interval|Last checked|Next check after|Mount count|Maximum mount count"

confirm "Change the check interval to 30 days?"

echo
echo "Running:"
echo "sudo tune2fs -i 30d $ROOT_DEV"

sudo tune2fs -i 30d "$ROOT_DEV"

echo
echo "Change completed."

confirm "Display the updated filesystem settings?"

echo
sudo tune2fs -l "$ROOT_DEV" | grep -E "Filesystem state|Check interval|Last checked|Next check after|Mount count|Maximum mount count"

echo
echo -e "${GREEN}Done!${EC}"
