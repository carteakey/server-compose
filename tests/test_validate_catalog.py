#!/usr/bin/env python3
"""Focused, non-mutating regression checks for the catalog validator."""

import os
import shutil
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "fixtures"


def compose_config(path: Path) -> subprocess.CompletedProcess[str]:
    if shutil.which("docker") is None:
        raise AssertionError("Docker is required for Compose fixture checks")
    return subprocess.run(
        ["docker", "compose", "-f", str(path), "config", "--quiet"],
        cwd=ROOT,
        env={**os.environ, "COMPOSE_DISABLE_ENV_FILE": "1"},
        capture_output=True,
        text=True,
        check=False,
    )


class ComposeFixtureTests(unittest.TestCase):
    def test_valid_fixture_passes_config_without_starting(self) -> None:
        result = compose_config(FIXTURES / "valid-compose.yml")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_invalid_fixture_reports_parser_error(self) -> None:
        path = FIXTURES / "invalid-compose.yml"
        result = compose_config(path)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("environment must be a mapping", result.stderr)
        self.assertIn(str(path), result.stderr)


if __name__ == "__main__":
    unittest.main()
