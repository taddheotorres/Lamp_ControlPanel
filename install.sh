#!/usr/bin/env bash
#
# crystalctl installer
# Supports Debian, Ubuntu, Linux Mint, Arch Linux, Fedora, and openSUSE.
#

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}${BOLD}"
echo "================================================================="
echo "                     CRYSTALCTL INSTALLER                        "
echo "================================================================="
echo -e "${NC}"

# Check for root / sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Notice: Root privileges are required to install system binaries and desktop entries.${NC}"
    echo -e "${CYAN}Re-running installer with sudo...${NC}\n"
    exec sudo "$0" "$@"
fi

TARGET_USER="${SUDO_USER:-$USER}"

# The panel only needs Python 3.8+ and systemd; services themselves are installed later with `crystalctl install`
detect_distro_and_install_deps() {
    echo -e "${BLUE}[1/5] Checking dependencies...${NC}"
    if python3 -c 'import sys; sys.exit(sys.version_info < (3, 8))' 2>/dev/null; then
        echo -e "${GREEN}[OK] $(python3 --version) found.${NC}"
    elif command -v apt-get &>/dev/null; then
        apt-get update && apt-get install -y python3
    elif command -v dnf &>/dev/null; then
        dnf install -y python3
    elif command -v pacman &>/dev/null; then
        pacman -S --needed --noconfirm python
    elif command -v zypper &>/dev/null; then
        zypper --non-interactive install python3
    else
        echo -e "${RED}Python 3.8+ is required. Install it and run this script again.${NC}"
        exit 1
    fi
    command -v systemctl &>/dev/null || { echo -e "${RED}systemd is required.${NC}"; exit 1; }
}

# Names used before the rename to crystalctl; removed so the old `lamp` command does not linger
LEGACY_FILES=(/usr/local/bin/lamp /usr/local/bin/lamp-gui /usr/local/lib/lamp-control /usr/local/share/lamp-control
              /usr/share/applications/lamp-control-panel.desktop /usr/share/applications/lamp-www.desktop
              /usr/share/icons/hicolor/scalable/apps/lamp-control.svg /usr/share/pixmaps/lamp-control.svg)

install_binaries() {
    echo -e "\n${BLUE}[2/5] Installing crystalctl...${NC}"
    rm -rf "${LEGACY_FILES[@]}"
    install -m 755 "${SCRIPT_DIR}/bin/crystalctl" /usr/local/bin/crystalctl
    install -m 755 "${SCRIPT_DIR}/bin/crystalctl-gui" /usr/local/bin/crystalctl-gui
    install -D -m 644 "${SCRIPT_DIR}/lib/crystal_core.py" /usr/local/lib/crystalctl/crystal_core.py
    install -D -m 644 "${SCRIPT_DIR}/gui/panel.html" /usr/local/share/crystalctl/panel.html
    echo -e "${GREEN}[OK] Installed /usr/local/bin/crystalctl (CLI) and crystalctl-gui (panel)${NC}"
}

install_desktop_entries() {
    echo -e "\n${BLUE}[3/5] Installing desktop shortcuts & icons...${NC}"
    mkdir -p /usr/share/applications /usr/share/icons/hicolor/scalable/apps /usr/share/pixmaps
    install -m 644 "${SCRIPT_DIR}/desktop/crystalctl.desktop" /usr/share/applications/crystalctl.desktop
    install -m 644 "${SCRIPT_DIR}/desktop/crystalctl-www.desktop" /usr/share/applications/crystalctl-www.desktop
    install -m 644 "${SCRIPT_DIR}/assets/crystalctl.svg" /usr/share/icons/hicolor/scalable/apps/crystalctl.svg
    install -m 644 "${SCRIPT_DIR}/assets/crystalctl.svg" /usr/share/pixmaps/crystalctl.svg

    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database /usr/share/applications 2>/dev/null || true
    fi
    if command -v gtk-update-icon-cache &>/dev/null; then
        gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true
    fi
    echo -e "${GREEN}[OK] Desktop launchers and icon installed.${NC}"
}

configure_web_permissions() {
    echo -e "\n${BLUE}[4/5] Configuring web root permissions (/var/www/html)...${NC}"
    mkdir -p /var/www/html
    
    if id "$TARGET_USER" &>/dev/null; then
        if getent group www-data &>/dev/null; then
            usermod -aG www-data "$TARGET_USER" || true
            chown -R "$TARGET_USER":www-data /var/www/html 2>/dev/null || true
            chmod -R 775 /var/www/html 2>/dev/null || true
            echo -e "${GREEN}[OK] Configured /var/www/html permissions for user '${TARGET_USER}' (group www-data).${NC}"
        else
            chown -R "$TARGET_USER" /var/www/html 2>/dev/null || true
        fi
    fi
}

install_dashboard_template() {
    echo -e "\n${BLUE}[5/5] Checking localhost start page (/var/www/html/index.php)...${NC}"
    if [ -f "${SCRIPT_DIR}/web/index.php" ]; then
        if [ ! -f /var/www/html/index.php ]; then
            cp "${SCRIPT_DIR}/web/index.php" /var/www/html/index.php
            chown "$TARGET_USER":www-data /var/www/html/index.php 2>/dev/null || true
            chmod 664 /var/www/html/index.php 2>/dev/null || true
            echo -e "${GREEN}[OK] Installed the dark localhost dashboard to /var/www/html/index.php${NC}"
        else
            echo -e "${CYAN}An existing /var/www/html/index.php was detected.${NC}"
            read -r -p "Do you want to update it with the dark localhost dashboard? (Existing file will be backed up) [y/N] " res_dash
            if [[ "$res_dash" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                cp /var/www/html/index.php /var/www/html/index.php.backup."$(date +%s)"
                cp "${SCRIPT_DIR}/web/index.php" /var/www/html/index.php
                chown "$TARGET_USER":www-data /var/www/html/index.php 2>/dev/null || true
                chmod 664 /var/www/html/index.php 2>/dev/null || true
                echo -e "${GREEN}[OK] Updated /var/www/html/index.php (backup saved).${NC}"
            else
                echo -e "${YELLOW}Kept existing /var/www/html/index.php.${NC}"
            fi
        fi
    fi
}

detect_distro_and_install_deps
install_binaries
install_desktop_entries
configure_web_permissions
install_dashboard_template

echo -e "\n${GREEN}${BOLD}=================================================================${NC}"
echo -e "${GREEN}${BOLD}                 CRYSTALCTL INSTALLED SUCCESSFULLY               ${NC}"
echo -e "${GREEN}${BOLD}=================================================================${NC}"
echo -e "\n${BOLD}How to use:${NC}"
echo -e "  - ${CYAN}crystalctl gui${NC}                 Open the panel"
echo -e "  - ${CYAN}crystalctl status${NC}              Live state of your installed services"
echo -e "  - ${CYAN}crystalctl list${NC}                Everything it can manage or install"
echo -e "  - ${CYAN}crystalctl install postgresql${NC}  Install a service with your package manager"
echo -e "  - ${CYAN}crystalctl help${NC}                All commands\n"
echo -e "Application launcher: search for ${BOLD}'crystalctl'${NC} in your application menu."
