#!/bin/bash
# JulesOS Recovery Interface (BSOD Replacement)
# Launched automatically by jules_shell on a Rust panic.

# Set Colors
RED='\033[1;31m'
WHITE='\033[1;37m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CRASH_FILE="/home/jules/Desktop/CRASH_REPORT.log"

clear
echo -e "${RED}════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}                          JULES OS RECOVERY SCREEN                              ${NC}"
echo -e "${RED}════════════════════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${WHITE}A critical system component (PID 1) has crashed.${NC}"
echo -e "${YELLOW}To protect the system from a Kernel Panic, execution has been suspended.${NC}"
echo ""

if [ -f "$CRASH_FILE" ]; then
    echo -e "${BLUE}--- CRASH REPORT ---${NC}"
    cat "$CRASH_FILE"
    echo -e "${BLUE}--------------------${NC}"
else
    echo -e "${RED}Error: Crash log not found at $CRASH_FILE${NC}"
fi

echo ""
echo -e "${WHITE}What would you like to do?${NC}"
echo "  1) Restart Jules Shell (Attempt Recovery)"
echo "  2) Reboot System"
echo "  3) Power Off"
echo "  4) Generate GitHub Issue Payload (Requires internet & manual submission)"
echo ""

while true; option=""; do
    read -p "Select an option [1-4]: " option
    case $option in
        1)
            echo -e "${GREEN}Attempting to restart shell...${NC}"
            exec /bin/jules_shell
            ;;
        2)
            echo -e "${YELLOW}Rebooting...${NC}"
            # Because PID 1 is dead, normal reboot might fail. We use SysRq as fallback.
            echo b > /proc/sysrq-trigger 2>/dev/null || reboot -f
            ;;
        3)
            echo -e "${YELLOW}Powering off...${NC}"
            echo o > /proc/sysrq-trigger 2>/dev/null || poweroff -f
            ;;
        4)
            echo ""
            echo -e "${WHITE}--- GitHub Automated Issue ---${NC}"
            echo "Since hardcoding an Access Token is a security risk, copy the following JSON payload"
            echo "and submit it via your browser or the GitHub API:"
            echo ""
            echo -e "${YELLOW}curl -L \\"
            echo "  -X POST \\"
            echo "  -H 'Accept: application/vnd.github+json' \\"
            echo "  -H 'Authorization: Bearer YOUR_TOKEN_HERE' \\"
            echo "  -H 'X-GitHub-Api-Version: 2022-11-28' \\"
            echo "  https://api.github.com/repos/JONIMONI09/JulesOS/issues \\"
            echo "  -d '{\"title\":\"Automated Crash Report (PID 1)\",\"body\":\"\`\`\`\n$(cat "$CRASH_FILE" | tr '\n' ' ' | sed 's/"/\\"/g')\n\`\`\`\",\"labels\":[\"bug\"]}'${NC}"
            echo ""
            echo "Press ENTER to return."
            read -r
            ;;
        *)
            echo -e "${RED}Invalid option.${NC}"
            ;;
    esac
done
