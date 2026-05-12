#!/usr/bin/env python3
"""Integration tests for the SAFE rebar3 plugin.

Runs rebar3 safe commands in fixture projects and verifies outputs.

Usage:
    python3 scripts/integration_test.py        # run all tests
    python3 scripts/integration_test.py -v     # verbose
"""

import os
import shutil
import subprocess
import sys
import unittest

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
FIXTURES_DIR = os.path.join(PROJECT_ROOT, "fixtures")
FIXTURES = ["my_app", "my_umbrella"]


def rebar3_safe(fixture_name, *args, timeout=120):
    """Run `rebar3 safe <args>` in a fixture directory.

    Returns (exit_code, combined_output).
    """
    fixture_dir = os.path.join(FIXTURES_DIR, fixture_name)
    cmd = ["rebar3", "safe"] + list(args)
    result = subprocess.run(
        cmd,
        cwd=fixture_dir,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    output = result.stdout + result.stderr
    return result.returncode, output


def setup_checkouts(fixture_name):
    """Create _checkouts/safe symlink so the fixture uses the local plugin."""
    fixture_dir = os.path.join(FIXTURES_DIR, fixture_name)
    checkouts_dir = os.path.join(fixture_dir, "_checkouts")
    symlink_path = os.path.join(checkouts_dir, "safe")
    os.makedirs(checkouts_dir, exist_ok=True)
    if not os.path.islink(symlink_path):
        os.symlink("../../..", symlink_path)


def cleanup_checkouts(fixture_name):
    """Remove _checkouts/safe symlink."""
    fixture_dir = os.path.join(FIXTURES_DIR, fixture_name)
    symlink_path = os.path.join(fixture_dir, "_checkouts", "safe")
    if os.path.islink(symlink_path):
        os.remove(symlink_path)
    checkouts_dir = os.path.join(fixture_dir, "_checkouts")
    if os.path.isdir(checkouts_dir):
        try:
            os.rmdir(checkouts_dir)
        except OSError:
            pass


def cleanup_build(fixture_name):
    """Remove _build directory from a fixture."""
    build_dir = os.path.join(FIXTURES_DIR, fixture_name, "_build")
    if os.path.isdir(build_dir):
        shutil.rmtree(build_dir)


def clean_fingerprint(fixture_name):
    """Remove fingerprint.json file from a fixture."""
    fingerprint_path = os.path.join(FIXTURES_DIR, fixture_name, "fingerprint.json")
    if os.path.isfile(fingerprint_path):
        os.remove(fingerprint_path)


def setUpModule():
    """Compile the plugin and set up checkouts for all fixtures."""
    for fixture in FIXTURES:
        cleanup_build(fixture)
        clean_fingerprint(fixture)
    print("Compiling SAFE plugin...")
    result = subprocess.run(
        ["rebar3", "compile"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        timeout=120,
    )
    if result.returncode != 0:
        print(result.stdout + result.stderr, file=sys.stderr)
        raise RuntimeError("Plugin compilation failed")
    for fixture in FIXTURES:
        setup_checkouts(fixture)


def tearDownModule():
    """Clean up checkouts and build dirs for all fixtures."""
    for fixture in FIXTURES:
        cleanup_checkouts(fixture)
        cleanup_build(fixture)
        clean_fingerprint(fixture)


# ------------------------------------------------------------------------------
# common tests e.g. help, error cases
# -------------------------------------------------------------------------------
class TestCommon(unittest.TestCase):
    fixture = "my_app"

    # -- help --
    def test_help(self):
        code, output = rebar3_safe(self.fixture, "help")
        self.assertEqual(0, code, output)
        self.assertIn("SAFE security vulnerability scanner", output)

    # -- error cases --
    def test_no_task(self):
        code, output = rebar3_safe(self.fixture)
        self.assertNotEqual(0, code, output)
        self.assertIn("No task specified", output)

    def test_unrecognised_task(self):
        code, output = rebar3_safe(self.fixture, "foobar")
        self.assertNotEqual(0, code, output)
        self.assertIn("Unrecognised task", output)


# ------------------------------------------------------------------------------
# my_app tests
# ------------------------------------------------------------------------------
class TestMyApp(unittest.TestCase):
    fixture = "my_app"

    def setUp(self):
        clean_fingerprint(self.fixture)

    # -- fingerprint --
    def test_fingerprint(self):
        fingerprint_path = os.path.join(FIXTURES_DIR, self.fixture, "fingerprint.json")
        self.assertFalse(
            os.path.isfile(fingerprint_path),
            "fingerprint.json should not exist before fingerprinting",
        )

        code, output = rebar3_safe(self.fixture, "fingerprint")
        self.assertEqual(0, code, output)
        self.assertIn("fingerprint complete", output.lower())

        self.assertTrue(
            os.path.isfile(fingerprint_path),
            "fingerprint.json should exist after fingerprinting",
        )

    # -- analyse --
    def test_analyse(self):
        code, output = rebar3_safe(self.fixture, "analyse")

        # The SAFE binary should be correctly invoked. With a valid license it succeeds (code 0);
        # without a license it fails with "License not found" (code 1).
        self.assertIn(code, [0, 1], output)
        if code == 0:
            self.assertIn("SAFE analysis complete", output)
        else:
            self.assertIn("License not found", output)


# ---------------------------------------------------------------------------
# my_umbrella tests
# ---------------------------------------------------------------------------
class TestMyUmbrella(unittest.TestCase):
    fixture = "my_umbrella"

    def setUp(self):
        clean_fingerprint(self.fixture)

    # -- fingerprint --
    def test_fingerprint(self):
        fingerprint_path = os.path.join(FIXTURES_DIR, self.fixture, "fingerprint.json")
        self.assertFalse(
            os.path.isfile(fingerprint_path),
            "fingerprint.json should not exist before fingerprinting",
        )

        code, output = rebar3_safe(self.fixture, "fingerprint")
        self.assertEqual(0, code, output)
        self.assertIn("fingerprint complete", output.lower())

        self.assertTrue(
            os.path.isfile(fingerprint_path),
            "fingerprint.json should exist after fingerprinting",
        )

    # -- analyse --
    def test_analyse(self):
        code, output = rebar3_safe(self.fixture, "analyse")

        # The SAFE binary should be correctly invoked. With a valid license it succeeds (code 0);
        # without a license it fails with "License not found" (code 1).
        self.assertIn(code, [0, 1], output)
        if code == 0:
            self.assertIn("SAFE analysis complete", output)
        else:
            self.assertIn("License not found", output)


if __name__ == "__main__":
    unittest.main()
