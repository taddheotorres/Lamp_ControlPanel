# LAMP Control Panel & CLI for Linux

<div align="center">

![Linux](https://img.shields.io/badge/OS-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Python](https://img.shields.io/badge/Python-3.x-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Apache](https://img.shields.io/badge/Apache-2.4-D22128?style=for-the-badge&logo=apache&logoColor=white)
![MariaDB](https://img.shields.io/badge/MariaDB-MySQL-003545?style=for-the-badge&logo=mariadb&logoColor=white)
![PHP](https://img.shields.io/badge/PHP-8.x-777BB4?style=for-the-badge&logo=php&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-00ff66?style=for-the-badge)

<br/>

**A lightweight, native, and minimalist LAMP stack manager for modern Linux distributions.**
<br/>
*Control Apache2, MariaDB/MySQL, and PHP with a dark-mode graphical control panel or directly from your terminal.*

</div>

---

## Features

- **Desktop GUI (`lamp-gui`)**:
  - Dark-mode interface.
  - Live module status indicators (Active / Inactive).
  - Real-time PID and port tracking (80, 443, 3306).
  - One-click Start, Stop, and Restart controls for Apache and MariaDB/MySQL.
  - Direct links to phpMyAdmin, configuration files, and system logs.
  - Embedded real-time system log output.

- **Full-featured CLI Tool (`lamp`)**:
  - Manage server state in milliseconds straight from your shell.
  - Formatted status reports, port detection, and quick action commands.

- **Localhost Web Dashboard (`web/index.php`)**:
  - Dark dashboard template for `http://localhost`.
  - Automatic project directory listing for `/var/www/html`.
  - System environment, PHP version, and database connectivity readout.

- **Desktop Integration**:
  - Native `.desktop` application launchers for app menus (Rofi, Wofi, GNOME, KDE, etc.).
  - Vector SVG application icon.
  - Privilege elevation support via Polkit (`pkexec`) and `sudo`.

- **Cross-Distro Compatibility**:
  - Automatic service detection for Debian/Ubuntu (`apache2`/`mariadb`), Arch Linux (`httpd`/`mariadb`), and Fedora/RHEL (`httpd`/`mariadb-server`).

---

## Project Structure

```text
Lamp_ControlPanel/
├── assets/
│   └── lamp-control.svg          # Vector application icon
├── bin/
│   ├── lamp                      # Terminal CLI control script
│   └── lamp-gui                  # Tkinter desktop GUI control panel
├── desktop/
│   ├── lamp-control-panel.desktop# Desktop menu entry for Control Panel
│   └── lamp-www.desktop          # Desktop shortcut to /var/www/html
├── web/
│   └── index.php                 # Localhost dark dashboard template
├── install.sh                    # Automated system installer
├── uninstall.sh                  # Clean uninstaller
├── .gitignore
├── LICENSE
└── README.md
```

---

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/taddheotorres/Lamp_ControlPanel.git
cd Lamp_ControlPanel
```

### 2. Run the Installer

```bash
chmod +x install.sh
sudo ./install.sh
```

The installer will:
1. Detect your Linux distribution and verify required packages (`apache2`, `mariadb-server`, `php`, `python3-tk`).
2. Install `lamp` and `lamp-gui` into `/usr/local/bin/`.
3. Install desktop application launchers and icons to `/usr/share/applications/` and `/usr/share/icons/`.
4. Configure `/var/www/html` permissions so you can create and edit web projects without `sudo`.
5. Optionally install the localhost start page.

---

## Usage

### Desktop GUI

Launch the GUI by running:
```bash
lamp-gui
```
*Or search for **"LAMP Control Panel"** in your application launcher (Rofi, GNOME App Grid, KDE Kickoff, etc.).*

---

### Terminal CLI Commands

The `lamp` command provides control from any terminal:

| Command | Description |
| :--- | :--- |
| `lamp start` | Starts all LAMP services (Apache & MariaDB/MySQL) |
| `lamp stop` | Stops all LAMP services |
| `lamp restart` | Restarts all LAMP services |
| `lamp status` | Shows status, PIDs, listening ports, and PHP info |
| `lamp gui` | Launches the graphical Control Panel in the background |
| `lamp web` | Opens `http://localhost` in your default browser |
| `lamp db` or `lamp pma` | Opens `http://localhost/phpmyadmin` in your default browser |
| `lamp dir` or `lamp www` | Opens `/var/www/html` in your default file manager |
| `lamp logs` | Displays recent lines of Apache error log |
| `lamp help` | Displays the help manual |

#### Example CLI Output:

```text
LAMP Control Utility [apache2 | mariadb | PHP]

Service Status:
  - Web Server (apache2):      [ACTIVE] (Running) [PID: 14820 14822] [Ports: 80, 443]
  - Database (mariadb):        [ACTIVE] (Running) [PID: 14610] [Port: 3306]
  - PHP Engine:                PHP 8.4.4
  - Web Root Directory:        /var/www/html
```

---

## Requirements

- **Linux OS:** Debian, Ubuntu, Linux Mint, Arch Linux, Fedora, openSUSE, etc.
- **Python 3:** With `python3-tk` (Tkinter graphical library).
- **Web Stack:**
  - Apache (`apache2` or `httpd`)
  - MariaDB or MySQL (`mariadb-server` / `mysql-server`)
  - PHP (`php`, `libapache2-mod-php`, `php-mysql`)
  - *(Optional)* phpMyAdmin

---

## Uninstallation

To completely remove the CLI, GUI, and desktop shortcuts:

```bash
sudo ./uninstall.sh
```

*(Note: Your web files in `/var/www/html` and database records will never be deleted by the uninstaller).*

---

## License

This project is licensed under the [MIT License](LICENSE) - see the LICENSE file for details.

Developed for the Linux and Open Source Community by [Taddheo Torres](https://github.com/taddheotorres).
