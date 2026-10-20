import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
import lamp_core as core  # noqa: E402

UNIT_FILES = """\
httpd.service                 enabled  disabled
php8.3-fpm.service            disabled disabled
mariadb.service               enabled  disabled
mariadb@.service              disabled disabled
mysql.service                 alias    -
mysqld.service                alias    -
valkey.service                disabled disabled
"""

SS = """\
LISTEN 0 511       0.0.0.0:80     0.0.0.0:*
LISTEN 0 80      127.0.0.1:3306   0.0.0.0:*
LISTEN 0 128          [::]:443       [::]:*
"""


class FakeRunner(core.Runner):
    def __init__(self, active=("httpd", "mariadb"), tools=("dnf", "pkexec"), paths=()):
        self.active, self.tools, self.paths, self.calls = set(active), set(tools), set(paths), []

    def run(self, cmd, timeout=30):
        self.calls.append(cmd)
        if cmd[:2] == ["systemctl", "list-unit-files"]:
            return 0, UNIT_FILES, ""
        if cmd[0] == "ss":
            return 0, SS, ""
        if cmd[:2] == ["systemctl", "show"]:
            on = cmd[2] in self.active
            return 0, (f"ActiveState={'active' if on else 'inactive'}\nSubState={'running' if on else 'dead'}\n"
                       f"UnitFileState=enabled\nMainPID={'42' if on else '0'}\n"), ""
        return 0, "", ""

    def which(self, name):
        return f"/usr/bin/{name}" if name in self.tools else None

    def exists(self, path):
        return path in self.paths


class CatalogTest(unittest.TestCase):
    def test_aliases_and_templates_are_not_units(self):
        units = core.unit_files(FakeRunner())
        self.assertEqual(units, ["httpd", "php8.3-fpm", "mariadb", "valkey"])

    def test_versioned_and_renamed_units_are_found(self):
        units = core.unit_files(FakeRunner())
        self.assertEqual(core.find_unit(core.by_id("php-fpm"), units), "php8.3-fpm")
        self.assertEqual(core.find_unit(core.by_id("redis"), units), "valkey")
        self.assertIsNone(core.find_unit(core.by_id("mysql"), units))  # only an alias of mariadb here

    def test_listening_ports_parse_ipv4_and_ipv6(self):
        self.assertEqual(core.listening_ports(FakeRunner()), {80, 443, 3306})

    def test_status_reports_live_state_and_only_listening_default_ports(self):
        by = {s["id"]: s for s in core.status(FakeRunner(paths={"/etc/httpd/conf/httpd.conf", "/usr/share/phpmyadmin"}))}
        self.assertTrue(by["apache"]["installed"])
        self.assertEqual(by["apache"]["ports"], [80, 443])
        self.assertEqual(by["apache"]["pid"], 42)
        self.assertEqual(by["apache"]["config"], "/etc/httpd/conf/httpd.conf")
        self.assertEqual(by["mariadb"]["admin"]["label"], "phpMyAdmin")
        self.assertEqual(by["redis"]["active"], "inactive")
        self.assertEqual(by["redis"]["ports"], [])
        self.assertFalse(by["postgresql"]["installed"])
        self.assertTrue(by["postgresql"]["installable"])
        self.assertFalse(by["mongodb"]["installable"])

    def test_every_service_has_a_unique_id_and_known_kind(self):
        ids = [s.id for s in core.CATALOG]
        self.assertEqual(len(ids), len(set(ids)))
        kinds = {k for k, _ in core.KINDS}
        self.assertTrue(all(s.kind in kinds for s in core.CATALOG))


class CommandTest(unittest.TestCase):
    def test_install_plans(self):
        self.assertEqual(core.install_commands("postgresql", "dnf"),
                         [["dnf", "install", "-y", "postgresql-server"], ["postgresql-setup", "--initdb"]])
        self.assertEqual(core.install_commands("nginx", "apt"),
                         [["apt-get", "update"], ["apt-get", "install", "-y", "nginx"]])
        self.assertEqual(core.install_commands("phpmyadmin", "pacman"),
                         [["pacman", "-S", "--needed", "--noconfirm", "phpmyadmin"]])

    def test_install_refuses_what_the_distro_does_not_ship(self):
        for sid, pm in (("mysql", "pacman"), ("mongodb", "apt"), ("adminer", "dnf"), ("nginx", None)):
            with self.assertRaises(ValueError, msg=(sid, pm)):
                core.install_commands(sid, pm)
        with self.assertRaises(KeyError):
            core.install_commands("not-a-service", "apt")

    def test_action_commands(self):
        units = ["httpd", "mariadb"]
        self.assertEqual(core.action_command("apache", "restart", units), ["systemctl", "restart", "httpd"])
        self.assertEqual(core.action_command("mariadb", "enable", units), ["systemctl", "enable", "--now", "mariadb"])
        with self.assertRaises(ValueError):
            core.action_command("apache", "rm -rf /", units)
        with self.assertRaises(ValueError):
            core.action_command("nginx", "start", units)

    def test_package_manager_detection(self):
        self.assertEqual(core.package_manager(FakeRunner(tools=("pacman",))), "pacman")
        self.assertIsNone(core.package_manager(FakeRunner(tools=())))

    @unittest.skipIf(os.geteuid() == 0, "root needs no prefix")
    def test_privilege_prefix(self):
        self.assertEqual(core.privileged(["x"], gui=True, runner=FakeRunner()), ["pkexec", "x"])
        self.assertEqual(core.privileged(["x"], gui=True, runner=FakeRunner(tools=())), ["sudo", "x"])
        self.assertEqual(core.privileged(["x"], runner=FakeRunner()), ["sudo", "x"])


if __name__ == "__main__":
    unittest.main()
