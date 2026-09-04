#!/usr/bin/env bash
#
# LAMP Control Panel & CLI Uninstaller
#

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Root privileges required to uninstall system files.${NC}"
    exec sudo "$0" "$@"
fi

echo -e "${RED}${BOLD}Uninstalling LAMP Control Panel...${NC}\n"

# Remove binaries
rm -f /usr/local/bin/lamp
rm -f /usr/local/bin/lamp-gui
echo -e "${GREEN}[OK] Removed /usr/local/bin/lamp and /usr/local/bin/lamp-gui${NC}"

# Remove desktop entries and icons
rm -f /usr/share/applications/lamp-control-panel.desktop
rm -f /usr/share/applications/lamp-www.desktop
rm -f /usr/share/icons/hicolor/scalable/apps/lamp-control.svg
rm -f /usr/share/pixmaps/lamp-control.svg
echo -e "${GREEN}[OK] Removed desktop shortcuts and application icons${NC}"

# Update desktop database
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database /usr/share/applications 2>/dev/null || true
fi
if command -v gtk-update-icon-cache &>/dev/null; then
    gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true
fi

echo -e "\n${GREEN}${BOLD}[OK] LAMP Control Panel uninstalled successfully.${NC}"
echo -e "${CYAN}Note: Your web files in /var/www/html and database data were preserved.${NC}"
