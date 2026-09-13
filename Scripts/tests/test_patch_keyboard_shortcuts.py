import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PATCHER = Path(__file__).resolve().parents[1] / "patch_keyboard_shortcuts.py"
UPSTREAM = 'NSLocalizedString(self, bundle: .module, comment: self)\n'


class ResourcePatchTests(unittest.TestCase):
    def test_replaces_legacy_patch_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as temporary:
            checkout = Path(temporary)
            utilities = checkout / "Sources/KeyboardShortcuts/Utilities.swift"
            utilities.parent.mkdir(parents=True)
            utilities.write_text(UPSTREAM)
            subprocess.run(["git", "init", "-q", str(checkout)], check=True)
            subprocess.run(["git", "-C", str(checkout), "add", "."], check=True)
            subprocess.run(
                ["git", "-C", str(checkout), "-c", "user.name=Fixture",
                 "-c", "user.email=fixture@example.invalid", "-c", "commit.gpgsign=false",
                 "commit", "-qm", "fixture"], check=True,
            )
            utilities.write_text(UPSTREAM.replace(".module", ".keyboardShortcutsSafeBundle"))

            command = [sys.executable, str(PATCHER), str(utilities)]
            subprocess.run(command, check=True)
            self.assertNotIn("keyboardShortcutsSafeBundle", utilities.read_text())
            first = utilities.read_bytes()
            modified = utilities.stat().st_mtime_ns
            subprocess.run(command, check=True)
            self.assertEqual(utilities.read_bytes(), first)
            self.assertEqual(utilities.stat().st_mtime_ns, modified)
            upstream = subprocess.check_output(
                ["git", "-C", str(checkout), "show", "HEAD:Sources/KeyboardShortcuts/Utilities.swift"]
            )
            self.assertEqual(upstream.decode(), UPSTREAM)


if __name__ == "__main__":
    unittest.main()
