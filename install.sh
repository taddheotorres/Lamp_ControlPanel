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

# Detect package manager
detect_distro_and_install_deps() {
    echo -e "${BLUE}[1/5] Checking dependencies...${NC}"

    if command -v apt-get &>/dev/null; then
        echo -e "${CYAN}Detected Debian/Ubuntu base system.${NC}"
        MISSING_PKGS=()
        for pkg in python3 python3-tk apache2 mariadb-server php libapache2-mod-php php-mysql; do
            if ! dpkg -l | grep -qw "$pkg"; then
                MISSING_PKGS+=("$pkg")
            fi
        done

        if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
            echo -e "${YELLOW}The following recommended packages are not installed: ${MISSING_PKGS[*]}${NC}"
            read -r -p "Do you want to install them now via apt? [Y/n] " response
            response=${response:-Y}
            if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                DEBIAN_FRONTEND=noninteractive apt-get update
                DEBIAN_FRONTEND=noninteractive apt-get install -y "${MISSING_PKGS[@]}"
            fi
        else
            echo -e "${GREEN}[OK] All core LAMP packages and Python Tkinter are installed.${NC}"
        fi

    elif command -v pacman &>/dev/null; then
        echo -e "${CYAN}Detected Arch Linux base system.${NC}"
        if ! command -v python3 &>/dev/null || ! pacman -Qi tk &>/dev/null; then
            echo -e "${YELLOW}Installing Python & Tkinter via pacman...${NC}"
            pacman -S --noconfirm --needed python tk apache mariadb php php-apache
        fi

    elif command -v dnf &>/dev/null; then
        echo -e "${CYAN}Detected Fedora/RHEL base system.${NC}"
        if ! command -v python3 &>/dev/null || ! rpm -q python3-tkinter &>/dev/null; then
            echo -e "${YELLOW}Installing Python & Tkinter via dnf...${NC}"
            dnf install -y python3 python3-tkinter httpd mariadb-server php php-mysqlnd
        fi
    fi
}

install_binaries() {
    echo -e "\n${BLUE}[2/5] Installing CLI and GUI binaries...${NC}"
    install -m 755 "${SCRIPT_DIR}/bin/lamp" /usr/local/bin/lamp
    install -m 755 "${SCRIPT_DIR}/bin/lamp-gui" /usr/local/bin/lamp-gui
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
