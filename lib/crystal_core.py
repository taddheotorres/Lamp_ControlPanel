"""
Service catalog and system access shared by the `crystalctl` CLI and the `crystalctl-gui` panel.

Everything that touches the system goes through `Runner`, so tests can swap it for a fake.
"""

import os
import re
import shutil
import subprocess
from dataclasses import dataclass, field

KINDS = [("web", "Web"), ("sql", "SQL databases"), ("nosql", "NoSQL & cache")]


@dataclass(frozen=True)
class Service:
    id: str
    name: str
    kind: str
    units: tuple            # regexes matched against systemd unit names, first match wins
    ports: tuple = ()       # default ports, checked against what is really listening
    configs: tuple = ()
    logs: tuple = ()
    packages: dict = field(default_factory=dict)       # package manager -> package list
    post_install: dict = field(default_factory=dict)   # package manager -> commands run once after install
    admin: tuple = ()       # (label, url, marker path that proves the panel is installed)


CATALOG = [
    Service("apache", "Apache", "web", (r"apache2", r"httpd"), (80, 443),
            ("/etc/apache2/apache2.conf", "/etc/httpd/conf/httpd.conf"),
            ("/var/log/apache2", "/var/log/httpd"),
            {"apt": ["apache2", "libapache2-mod-php"], "dnf": ["httpd", "php"],
             "pacman": ["apache", "php-apache"], "zypper": ["apache2", "apache2-mod_php8"]}),
    Service("nginx", "Nginx", "web", (r"nginx",), (80, 443),
            ("/etc/nginx/nginx.conf",), ("/var/log/nginx",),
            {"apt": ["nginx"], "dnf": ["nginx"], "pacman": ["nginx"], "zypper": ["nginx"]}),
    Service("php-fpm", "PHP-FPM", "web", (r"php[\d.]*-fpm", r"php-fpm"), (),
            ("/etc/php", "/etc/php-fpm.conf", "/etc/php/php-fpm.conf"), ("/var/log/php-fpm",),
            {"apt": ["php-fpm"], "dnf": ["php-fpm"], "pacman": ["php-fpm"], "zypper": ["php8-fpm"]}),
    Service("mariadb", "MariaDB", "sql", (r"mariadb",), (3306,),
            ("/etc/mysql/mariadb.cnf", "/etc/my.cnf", "/etc/my.cnf.d"), ("/var/log/mysql", "/var/log/mariadb"),
            {"apt": ["mariadb-server"], "dnf": ["mariadb-server"], "pacman": ["mariadb"], "zypper": ["mariadb"]},
            {"pacman": [["mariadb-install-db", "--user=mysql", "--basedir=/usr", "--datadir=/var/lib/mysql"]]},
            ("phpMyAdmin", "http://localhost/phpmyadmin", "/usr/share/phpmyadmin")),
    Service("mysql", "MySQL", "sql", (r"mysql", r"mysqld"), (3306, 33060),
            ("/etc/mysql/my.cnf", "/etc/mysql/mysql.conf.d/mysqld.cnf", "/etc/my.cnf"), ("/var/log/mysql",),
            # Arch and openSUSE ship no MySQL server in their official repos
            {"apt": ["mysql-server"], "dnf": ["community-mysql-server"]},
            {},
            ("phpMyAdmin", "http://localhost/phpmyadmin", "/usr/share/phpmyadmin")),
    Service("postgresql", "PostgreSQL", "sql", (r"postgresql",), (5432,),
            ("/etc/postgresql", "/var/lib/pgsql/data/postgresql.conf", "/var/lib/postgres/data/postgresql.conf"),
            ("/var/log/postgresql", "/var/lib/pgsql/data/log"),
            {"apt": ["postgresql"], "dnf": ["postgresql-server"], "pacman": ["postgresql"],
             "zypper": ["postgresql-server"]},
            # Debian initialises the cluster itself; the others need initdb before the first start
            {"dnf": [["postgresql-setup", "--initdb"]],
             "pacman": [["sudo", "-u", "postgres", "initdb", "-D", "/var/lib/postgres/data"]],
             "zypper": [["sudo", "-u", "postgres", "initdb", "-D", "/var/lib/pgsql/data"]]},
            ("Adminer", "http://localhost/adminer", "/usr/share/adminer")),
    Service("mongodb", "MongoDB", "nosql", (r"mongod", r"mongodb"), (27017,),
            ("/etc/mongod.conf",), ("/var/log/mongodb",),
            {}),  # not in any official distro repo (SSPL licence): manage-only
    Service("redis", "Redis / Valkey", "nosql", (r"redis-server", r"redis", r"valkey-server", r"valkey"), (6379,),
            ("/etc/redis/redis.conf", "/etc/redis.conf", "/etc/valkey/valkey.conf"),
            ("/var/log/redis", "/var/log/valkey"),
            # Fedora and Arch replaced Redis with its open fork Valkey
            {"apt": ["redis-server"], "dnf": ["valkey"], "pacman": ["valkey"], "zypper": ["redis"]}),
    Service("memcached", "Memcached", "nosql", (r"memcached",), (11211,),
            ("/etc/memcached.conf", "/etc/sysconfig/memcached"), (),
            {"apt": ["memcached"], "dnf": ["memcached"], "pacman": ["memcached"], "zypper": ["memcached"]}),
]

ADMIN_PANELS = {
    "phpmyadmin": {"apt": ["phpmyadmin"], "dnf": ["phpMyAdmin"], "pacman": ["phpmyadmin"], "zypper": ["phpMyAdmin"]},
    "adminer": {"apt": ["adminer"]},
}

ACTIONS = ("start", "stop", "restart", "enable", "disable")

INSTALL_CMD = {
    "apt": ["apt-get", "install", "-y"],
    "dnf": ["dnf", "install", "-y"],
    "pacman": ["pacman", "-S", "--needed", "--noconfirm"],
    "zypper": ["zypper", "--non-interactive", "install"],
}


class Runner:
    """Thin wrapper over subprocess so tests can fake the system."""

    def run(self, cmd, timeout=30):
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
            return res.returncode, res.stdout, res.stderr
        except (OSError, subprocess.TimeoutExpired) as e:
            return 127, "", str(e)

    def which(self, name):
        return shutil.which(name)

    def exists(self, path):
        return os.path.exists(path)


def by_id(service_id):
    for s in CATALOG:
        if s.id == service_id:
            return s
    raise KeyError(service_id)


def unit_files(runner):
    """Real service units only; aliases (Fedora's mysql.service -> mariadb) would show a service twice."""
    _, out, _ = runner.run(["systemctl", "list-unit-files", "--type=service", "--no-legend", "--plain"])
    units = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0].endswith(".service") and parts[1] != "alias" and "@." not in parts[0]:
            units.append(parts[0][: -len(".service")])
    return units


def find_unit(service, units):
    for pattern in service.units:
        for u in units:
            if re.fullmatch(pattern, u):
                return u
    return None


def listening_ports(runner):
    """Ports with a listening TCP socket. Without root `ss` cannot tell which process owns them."""
    _, out, _ = runner.run(["ss", "-ltnH"])
    ports = set()
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 4:
            m = re.search(r":(\d+)$", parts[3])
            if m:
                ports.add(int(m.group(1)))
    return ports


def unit_state(runner, unit):
    _, out, _ = runner.run(["systemctl", "show", unit, "-p", "ActiveState,SubState,UnitFileState,MainPID"])
    props = dict(line.split("=", 1) for line in out.splitlines() if "=" in line)
    return {
        "active": props.get("ActiveState", "unknown"),
        "sub": props.get("SubState", ""),
        "enabled": props.get("UnitFileState", "") == "enabled",
        "pid": int(pid) if (pid := props.get("MainPID", "0")).isdigit() and pid != "0" else None,
    }


def package_manager(runner):
    for pm in ("apt", "dnf", "pacman", "zypper"):
        if runner.which(INSTALL_CMD[pm][0]):
            return pm
    return None


def status(runner=None):
    """One snapshot of every catalog service: installed ones with live state, the rest with installability."""
    runner = runner or Runner()
    units = unit_files(runner)
    ports = listening_ports(runner)
    pm = package_manager(runner)
    out = []
    for s in CATALOG:
        unit = find_unit(s, units)
        item = {"id": s.id, "name": s.name, "kind": s.kind, "unit": unit, "installed": unit is not None,
                "installable": bool(pm and s.packages.get(pm))}
        if unit:
            item.update(unit_state(runner, unit))
            # shortcut: a default port counts as ours if something listens on it; run as root to map sockets to PIDs
            item["ports"] = [p for p in s.ports if p in ports] if item["active"] == "active" else []
            item["config"] = next((p for p in s.configs if runner.exists(p)), None)
            item["log"] = next((p for p in s.logs if runner.exists(p)), None)
            if s.admin and runner.exists(s.admin[2]):
                item["admin"] = {"label": s.admin[0], "url": s.admin[1]}
        out.append(item)
    return out


def privileged(cmd, gui=False, runner=None):
    """Prefix a command with pkexec (GUI, shows a desktop password prompt) or sudo (CLI)."""
    runner = runner or Runner()
    if os.geteuid() == 0:
        return list(cmd)
    if gui and runner.which("pkexec"):
        return ["pkexec"] + list(cmd)
    return ["sudo"] + list(cmd)


def action_command(service_id, action, units):
    if action not in ACTIONS:
        raise ValueError(f"unknown action: {action}")
    unit = find_unit(by_id(service_id), units)
    if not unit:
        raise ValueError(f"{service_id} is not installed")
    if action in ("enable", "disable"):
        return ["systemctl", action, "--now", unit]
    return ["systemctl", action, unit]


def install_commands(service_id, pm):
    """Commands, in order, that install a service and prepare it for its first start."""
    if service_id in ADMIN_PANELS:
        packages, post = ADMIN_PANELS[service_id].get(pm), []
    else:
        s = by_id(service_id)
        packages, post = s.packages.get(pm), s.post_install.get(pm, [])
    if not pm or not packages:
        raise ValueError(f"{service_id} cannot be installed with {pm or 'this system'}")
    cmds = []
    if pm == "apt":
        cmds.append(["apt-get", "update"])
    cmds.append(INSTALL_CMD[pm] + list(packages))
    cmds.extend(list(c) for c in post)
    return cmds


def logs_command(unit, lines=80):
    return ["journalctl", "-u", unit, "-n", str(lines), "--no-pager", "-o", "short-iso"]
