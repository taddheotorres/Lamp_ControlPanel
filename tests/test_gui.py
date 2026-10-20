import importlib.machinery
import importlib.util
import json
import os
import threading
import time
import unittest
import urllib.request
from http.server import ThreadingHTTPServer

from test_core import FakeRunner

HERE = os.path.dirname(__file__)
loader = importlib.machinery.SourceFileLoader("crystalctl_gui", os.path.join(HERE, "..", "bin", "crystalctl-gui"))
spec = importlib.util.spec_from_loader("crystalctl_gui", loader)
gui = importlib.util.module_from_spec(spec)
loader.exec_module(gui)


class PanelApiTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = gui.App(runner=FakeRunner())
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), gui.make_handler(cls.app))
        cls.app.port = cls.server.server_address[1]
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def call(self, path, body=None, token=None, host=None):
        req = urllib.request.Request(f"http://127.0.0.1:{self.app.port}{path}",
                                     data=json.dumps(body).encode() if body is not None else None)
        req.add_header("X-Crystal-Token", self.app.token if token is None else token)
        if host:
            req.add_header("Host", host)
        try:
            with urllib.request.urlopen(req) as r:
                return r.status, json.loads(r.read())
        except urllib.error.HTTPError as e:
            with e:
                return e.code, json.loads(e.read())

    def test_rejects_missing_token_and_foreign_host(self):
        self.assertEqual(self.call("/api/status", token="")[0], 403)
        self.assertEqual(self.call("/api/status", token="guess")[0], 403)
        self.assertEqual(self.call("/api/status", host=f"evil.test:{self.app.port}")[0], 403)
        self.assertEqual(self.call("/api/action", {"id": "apache", "action": "stop"}, token="")[0], 403)

    def test_status_lists_catalog(self):
        code, data = self.call("/api/status")
        self.assertEqual(code, 200)
        self.assertEqual({s["id"] for s in data["services"]}, {s.id for s in gui.core.CATALOG})
        self.assertEqual(data["pm"], "dnf")

    def test_rejects_unknown_services_and_actions(self):
        self.assertEqual(self.call("/api/action", {"id": "nope", "action": "start"})[0], 404)
        self.assertEqual(self.call("/api/action", {"id": "apache", "action": "format"})[0], 409)
        self.assertEqual(self.call("/api/install-plan?id=nope")[0], 404)
        self.assertEqual(self.call("/api/theme", {"theme": "neon"})[0], 409)

    def test_install_plan_comes_from_the_catalog(self):
        code, data = self.call("/api/install-plan?id=postgresql")
        self.assertEqual(code, 200)
        self.assertEqual(data["commands"][0], ["dnf", "install", "-y", "postgresql-server"])


class DemoModeTest(unittest.TestCase):
    def wait_idle(self, app):
        for _ in range(100):
            if not app.console.busy:
                return
            time.sleep(0.05)
        self.fail("task did not finish")

    def test_demo_shows_sample_services(self):
        by = {s["id"]: s for s in gui.core.status(gui.DemoRunner())}
        self.assertEqual(by["apache"]["active"], "active")
        self.assertEqual(by["apache"]["ports"], [80, 443])
        self.assertEqual(by["postgresql"]["active"], "inactive")
        self.assertEqual(by["mariadb"]["admin"]["label"], "phpMyAdmin")
        self.assertFalse(by["nginx"]["installed"])

    def test_demo_actions_change_only_memory(self):
        app = gui.App(gui.DemoRunner())
        self.assertTrue(app.demo)
        app.action("apache", "stop")
        self.wait_idle(app)
        app.action("postgresql", "enable")
        self.wait_idle(app)
        app.action("all", "restart")
        self.wait_idle(app)
        by = {s["id"]: s for s in gui.core.status(app.runner)}
        self.assertEqual(by["apache"]["active"], "inactive")  # stopped above; restart all must not revive it
        self.assertEqual(by["postgresql"]["active"], "active")
        self.assertTrue(by["postgresql"]["enabled"])
        app.open_path("apache", "config")  # must not launch a real editor
        self.assertIn("demo: would open", app.console.lines[-1]["text"])


if __name__ == "__main__":
    unittest.main()
