#!/usr/bin/env bash
##set -euo pipefail

# download and run:
# bash <(curl -fsSL https://raw.githubusercontent.com/jayshomebrew/bash-scripts/main/system/mintPolicykitAllowUpdates.bash)
#
# download and inspect:
# curl -fsSLO https://raw.githubusercontent.com/jayshomebrew/bash-scripts/main/system/mintPolicykitAllowUpdates.bash && less mintPolicykitAllowUpdates.bash
#

function doExit(){
    echo "exiting"
    exit
}


function pause(){
   read -p "Press <enter> to continue..."
}


function doColorAdd() {

    # Bright/High-Intensity Colors
    BRIGHTRED=$'\e[91m'
    BRIGHTGREEN=$'\e[92m'
    BRIGHTYELLOW=$'\e[93m'
    BRIGHTBLUE=$'\e[94m'
    BRIGHTPURPLE=$'\e[95m'
    BRIGHTCYAN=$'\e[96m'
    BRIGHTWHITE=$'\e[97m'

    # Bold Versions
    REDBOLD=$'\e[1;31m'
    GREENBOLD=$'\e[1;32m'
    YELLOWBOLD=$'\e[1;33m'
    BLUEBOLD=$'\e[1;34m'
    PURPLEBOLD=$'\e[1;35m'
    CYANBOLD=$'\e[1;36m'
    WHITEBOLD=$'\e[1;37m'
    ORANGEBOLD=$'\e[1;38;5;208m'

    # Reset
    EC=$'\e[0m'

    # Unicode symbols
    CHECKMARK="${BRIGHTGREEN}✔${EC}"
    XMARK="${BRIGHTRED}✖${EC}"

#echo -e "${REDBOLD}redbold${EC}"
#echo -e "${CHECKMARK} ${BRIGHTCYAN}GOOD${EC}"
#echo -e "${XMARK} ${BRIGHTRED}BAD${EC}"
}

doIntro(){

echo -e "${CYANBOLD}===================INTRODUCTION======================${EC}"
echo -e ""
echo -e "This script adds a file:"
echo -e "${BRIGHTBLUE}/etc/polkit-1/rules.d/50-allow-updates.rules${EC}"
echo -e
echo -e "and restarts the policykit to allow the sudo group (${PURPLEBOLD}${USER}${EC}) to run updates"
echo -e "without asking for a password."
echo -e ""
echo -e ""
echo -e "${CYANBOLD}=====================================================${EC}"

}

# ==============================================================================
# Function: doMintPolicykitAllowUpdates
# Description: Configures PolicyKit rules to allow the current user (or sudo group) 
#               to run update-manager or apt actions without needing a password,
#               if running on Linux Mint Cinnamon version 22.1 or newer.
# ==============================================================================
doMintPolicykitAllowUpdates() {
    echo -e "\n${CYANBOLD}--- Running PolicyKit Update Authorization Check ---${EC}"

    # Check for the required desktop environment (Cinnamon)
    if [[ "${XDG_CURRENT_DESKTOP}" != "X-Cinnamon" ]]; then
        echo -e "${BRIGHTYELLOW}Warning:${EC} This script is designed specifically for Cinnamon. Detected XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP}. Skipping policy configuration."
        return 0
    fi

    # --- Step 1: Determine Linux Mint Version ---
    echo -e "\n[INFO] Determining current operating system version..."
    local ver=""
    if command -v lsb_release >/dev/null; then
      # Use lsb_release if available (more reliable for distro info)
      ver=$(lsb_release -rs)
    else
      # Fallback to os-release file parsing
      ver=$(awk -F= '/^VERSION_ID=/ { gsub(/"/,"",$2); print $2 }' /etc/os-release)
    fi

    echo -e "[SUCCESS] Detected OS Version: ${YELLOWBOLD}${ver}${EC}"

    # --- Step 2: Check if Mint version is compatible (>= 22.1) ---
    if ! dpkg --compare-versions "$ver" ge "22.1"; then
        echo -e "${CYANBOLD}Skipping:${EC} Current Mint version (${ver}) is older than or equal to 22.1. PolicyKit rules might use a different structure."
        return 0
    fi

    # --- Step 3: Define and Apply Polkit Rules (Requires sudo) ---
    local POLKIT_FILE="/etc/polkit-1/rules.d/50-allow-updates.rules"
    echo -e "\n[ACTION] Checking PolicyKit rule file creation at: ${CYANBOLD}${POLKIT_FILE}${EC}"

    # User Acceptance Prompt for File Writing
    echo -e "${ORANGEBOLD}WARNING:${EC} This action requires writing to ${POLKIT_FILE} using 'sudo' "
    echo -e "and will allow passwordless updates."
    read -r -p "Continue? (y/Y or no): " confirm
    if [[ "$confirm" != [yY] ]]; then
        echo -e "${BRIGHTYELLOW}Operation aborted by user at the file writing stage.${EC}"
        return 1
    fi

    # The policy ruleset definition
    local RULE_SCRIPT='
// PolicyKit rule to allow non-interactive updates for members of 'sudo' group.
polkit.addRule(function(action, subject) {
    // Check if the action ID matches common update/package management actions 
    if (
        ( 
          action.id.startsWith("org.aptkit.install-or-remove-packages") ||
          action.id.startsWith("org.aptkit.upgrade-packages") ||
          action.id.startsWith("com.linuxmint.mintsources")
        )
        && subject.isInGroup("sudo")    // <-- IMPORTANT: Change "sudo" to your intended group if necessary
        && subject.active               // Only from an active local session
    ) {
        return polkit.Result.YES;
    }
});'

    # Execute the write operation with confirmation
    if sudo tee "$POLKIT_FILE" > /dev/null <<< "$RULE_SCRIPT"; then
        echo -e "${CHECKMARK} ${CYANBOLD}SUCCESS.${EC} Successfully created/overwrote PolicyKit rule file: ${BRIGHTYELLOW}${POLKIT_FILE}${EC}"
        echo "This allows members of the 'sudo' group to perform update actions without a password prompt."
    else
        echo -e "${REDBOLD}ERROR.${EC} Failed to write PolicyKit rules. Check permissions or if the path exists."
    fi


    # --- Step 4: Restart Polkit Service (Requires sudo) ---
    local RESTART_COMMAND="sudo systemctl restart polkit"
    echo -e "\n[ACTION] Attempting to restart the 'polkit' service to apply new rules..."

    # User Acceptance Prompt for Command Execution
    echo -e "${ORANGEBOLD}WARNING:${EC} This command will restart the PolicyKit daemon: ${RESTART_COMMAND}"
    echo -e "and will allow passwordless updates."
    read -r -p "Continue? (y/Y or no): " confirm
    if [[ "$confirm" != [yY] ]]; then
        echo -e "${BRIGHTYELLOW}Service restart skipped by user.${EC}"
        return 0
    fi

    # Execute the systemctl command
    if $RESTART_COMMAND; then
        echo -e "${CHECKMARK} ${CYANBOLD}SUCCESS.${EC} Polkit service successfully restarted."
    else
        echo -e "${REDBOLD}ERROR.${EC} Failed to restart polkit. You may need manual intervention or elevated privileges."
    fi

    echo -e "\n${BRIGHTGREEN}--- PolicyKit Configuration Complete ---${EC}"
}

# --- Execution Start ---
doColorAdd
doIntro
doMintPolicykitAllowUpdates



