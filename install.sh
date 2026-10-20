#!/usr/bin/env bash
#
# LAMP Control Panel & CLI Installer
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
echo "                  LAMP CONTROL PANEL INSTALLER                   "
echo "================================================================="
echo -e "${NC}"

# Check for root / sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Notice: Root privileges are required to install system binaries and desktop entries.${NC}"
    echo -e "${CYAN}Re-running installer with sudo...${NC}\n"
    exec sudo "$0" "$@"
fi

TARGET_USER="${SUDO_USER:-$USER}"

# The panel only needs Python 3.8+ and systemd; services themselves are installed later with `lamp install`
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

install_binaries() {
    echo -e "\n${BLUE}[2/5] Installing CLI and GUI binaries...${NC}"
    install -m 755 "${SCRIPT_DIR}/bin/lamp" /usr/local/bin/lamp
    install -m 755 "${SCRIPT_DIR}/bin/lamp-gui" /usr/local/bin/lamp-gui
    install -D -m 644 "${SCRIPT_DIR}/lib/lamp_core.py" /usr/local/lib/lamp-control/lamp_core.py
    install -D -m 644 "${SCRIPT_DIR}/gui/panel.html" /usr/local/share/lamp-control/panel.html
    echo -e "${GREEN}[OK] Installed /usr/local/bin/lamp (CLI)${NC}"
    echo -e "${GREEN}[OK] Installed /usr/local/bin/lamp-gui (GUI)${NC}"
}

install_desktop_entries() {
    echo -e "\n${BLUE}[3/5] Installing desktop shortcuts & icons...${NC}"
    mkdir -p /usr/share/applications /usr/share/icons/hicolor/scalable/apps /usr/share/pixmaps

    install -m 644 "${SCRIPT_DIR}/desktop/lamp-control-panel.desktop" /usr/share/applications/lamp-control-panel.desktop
    install -m 644 "${SCRIPT_DIR}/desktop/lamp-www.desktop" /usr/share/applications/lamp-www.desktop
    
    if [ -f "${SCRIPT_DIR}/assets/lamp-control.svg" ]; then
        install -m 644 "${SCRIPT_DIR}/assets/lamp-control.svg" /usr/share/icons/hicolor/scalable/apps/lamp-control.svg
        install -m 644 "${SCRIPT_DIR}/assets/lamp-control.svg" /usr/share/pixmaps/lamp-control.svg
    fi

    # Refresh desktop database & icon cache
    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database /usr/share/applications 2>/dev/null || true
    fi
    if command -v gtk-update-icon-cache &>/dev/null; then
        gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true
    fi
    echo -e "${GREEN}[OK] Desktop launchers and application icon installed successfully.${NC}"
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
            echo -e "${GREEN}[OK] Installed modern dark LAMP dashboard to /var/www/html/index.php${NC}"
        else
            echo -e "${CYAN}An existing /var/www/html/index.php was detected.${NC}"
            read -r -p "Do you want to update it with the clean dark LAMP dashboard? (Existing file will be backed up) [y/N] " res_dash
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
echo -e "${GREEN}${BOLD}             LAMP CONTROL PANEL INSTALLED SUCCESSFULLY!          ${NC}"
echo -e "${GREEN}${BOLD}=================================================================${NC}"
echo -e "\n${BOLD}How to use:${NC}"
echo -e "  - ${CYAN}lamp-gui${NC}         Launch graphical Control Panel"
echo -e "  - ${CYAN}lamp start${NC}       Start all LAMP services"
echo -e "  - ${CYAN}lamp status${NC}      Check server status and active ports"
echo -e "  - ${CYAN}lamp web${NC}         Open http://localhost in browser"
echo -e "  - ${CYAN}lamp db${NC}          Open phpMyAdmin (http://localhost/phpmyadmin)"
echo -e "  - ${CYAN}lamp help${NC}        Show all available CLI options\n"
echo -e "Application launcher: Search for ${BOLD}'LAMP Control Panel'${NC} in your application menu (Rofi/Wofi/GNOME/KDE)."
