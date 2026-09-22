import os
import subprocess
import tempfile
import unittest
from pathlib import Path

INSTALLER = Path(__file__).resolve().parents[1] / "install_swift_ci.sh"


class SwiftInstallerTests(unittest.TestCase):
    def test_other_trusted_publisher_never_runs_installer(self):
        self.run_fixture(
            "Darwin",
            {"pkgutil": "echo checked >> \"$TEST_TRACE\"\n"
             "printf '%s\\n' 'Status: signed by a certificate trusted by macOS' "
             "'Certificate Chain:' '  1. Developer ID Installer: Other Publisher (OTHERTEAM1)'"},
            "checked\n",
        )

    def test_swift_publisher_reaches_installer(self):
        self.run_fixture(
            "Darwin",
            {"pkgutil": "echo checked >> \"$TEST_TRACE\"\n"
             "printf '%s\\n' 'Status: signed by a certificate trusted by macOS' "
             "'Certificate Chain:' '  1. Developer ID Installer: Swift Open Source (V9AUD2URP3)'"},
            "checked\ninstalled\n",
            expected_code=77,
        )

    def test_invalid_signature_never_extracts_or_changes_path(self):
        self.run_fixture(
            "Linux",
            {"gpg": 'case "$*" in *--verify*) echo verify >> "$TEST_TRACE"; exit 1;; *) exit 0;; esac'},
            "verify\n",
        )

    def test_release_without_patch_number_is_supported(self):
        self.run_fixture(
            "Linux",
            {"gpg": 'case "$*" in *--verify*) echo verify >> "$TEST_TRACE"; exit 1;; *) exit 0;; esac'},
            "verify\n",
            version="6.3",
        )

    def test_zero_patch_release_accepts_equivalent_compiler_version(self):
        for reported in ["6.4", "6.4.0"]:
            with self.subTest(reported=reported):
                self.run_fixture(
                    "Linux", {"gpg": "exit 0"}, "extracted\n",
                    expected_code=0, version="6.4.0", reported_version=reported,
                )

    def test_other_compiler_versions_are_rejected(self):
        for requested, reported in [("6.4.0", "6.4.1"), ("6.4.0", "6.3"), ("6.0", "6")]:
            with self.subTest(requested=requested, reported=reported):
                self.run_fixture(
                    "Linux", {"gpg": "exit 0"}, "extracted\n",
                    expected_code=1, version=requested, reported_version=reported,
                )

    def run_fixture(self, platform, extra_commands, expected_trace, expected_code=None,
                    version="6.3.3", reported_version=None):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            commands = root / "bin"
            commands.mkdir()
            runner = root / "runner"
            runner.mkdir()
            installed = runner / f"swift-{version}-RELEASE"
            if reported_version is not None:
                compiler = installed / "usr/bin/swift"
                compiler.parent.mkdir(parents=True)
                compiler.write_text(f"#!/bin/sh\necho 'Swift version {reported_version} (test-RELEASE)'\n")
                compiler.chmod(0o755)
            trace = root / "trace"
            github_path = root / "github-path"
            github_path.write_text("existing-path\n")
            stubs = {
                "uname": f'case "$1" in -s) echo {platform};; -m) echo x86_64;; esac',
                "curl": '''while [ "$#" -gt 0 ]; do
                    if [ "$1" = "-o" ]; then printf download > "$2"; exit 0; fi
                    shift
                done
                exit 1''',
                "tar": 'echo extracted >> "$TEST_TRACE"',
                "sudo": 'echo installed >> "$TEST_TRACE"; exit 77',
                **extra_commands,
            }
            for name, script in stubs.items():
                command = commands / name
                command.write_text("#!/bin/sh\n" + script + "\n")
                command.chmod(0o755)
            result = subprocess.run(
                ["/bin/bash", str(INSTALLER), version],
                env={
                    "PATH": str(commands) + os.pathsep + "/usr/bin:/bin",
                    "RUNNER_TEMP": str(runner),
                    "GITHUB_PATH": str(github_path),
                    "GITHUB_ENV": str(root / "github-env"),
                    "TEST_TRACE": str(trace),
                },
                capture_output=True,
                text=True,
            )
            if expected_code is None:
                self.assertNotEqual(result.returncode, 0)
            else:
                self.assertEqual(result.returncode, expected_code, result.stderr)
            self.assertEqual(trace.read_text(), expected_trace)
            expected_path = "existing-path\n"
            if expected_code == 0:
                expected_path += str(installed / "usr/bin") + "\n"
            self.assertEqual(github_path.read_text(), expected_path)
            self.assertEqual(list(runner.iterdir()), [installed] if reported_version is not None else [])


if __name__ == "__main__":
    unittest.main()
