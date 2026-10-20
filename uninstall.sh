#!/usr/bin/env bash
#
# crystalctl uninstaller
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

echo -e "${RED}${BOLD}Uninstalling crystalctl...${NC}\n"

# Current names, plus the ones used before the rename to crystalctl
rm -rf /usr/local/bin/crystalctl /usr/local/bin/crystalctl-gui /usr/local/lib/crystalctl /usr/local/share/crystalctl \
       /usr/local/bin/lamp /usr/local/bin/lamp-gui /usr/local/lib/lamp-control /usr/local/share/lamp-control
echo -e "${GREEN}[OK] Removed crystalctl and crystalctl-gui${NC}"

rm -f /usr/share/applications/crystalctl.desktop /usr/share/applications/crystalctl-www.desktop \
      /usr/share/icons/hicolor/scalable/apps/crystalctl.svg /usr/share/pixmaps/crystalctl.svg \
      /usr/share/applications/lamp-control-panel.desktop /usr/share/applications/lamp-www.desktop \
      /usr/share/icons/hicolor/scalable/apps/lamp-control.svg /usr/share/pixmaps/lamp-control.svg
echo -e "${GREEN}[OK] Removed desktop shortcuts and icons${NC}"

# Update desktop database
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database /usr/share/applications 2>/dev/null || true
fi
if command -v gtk-update-icon-cache &>/dev/null; then
    gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true
fi

echo -e "\n${GREEN}${BOLD}[OK] crystalctl uninstalled.${NC}"
echo -e "${CYAN}Note: Your web files, databases and ~/.config/crystalctl were kept.${NC}"
