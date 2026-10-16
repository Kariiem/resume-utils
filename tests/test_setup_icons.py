"""Offline checks for icon setup; never download or modify the real assets."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class IconSetupTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        for name in ("setup-icons.sh", "icons.sha256"):
            shutil.copyfile(ROOT / name, self.root / name)

    def run_setup(self, *args):
        return subprocess.run(["bash", str(self.root / "setup-icons.sh"), *args],
                              capture_output=True, text=True)

    def copy_assets(self):
        for line in (self.root / "icons.sha256").read_text().splitlines():
            _, relative = line.split()
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)

    def test_help_and_invalid_arguments_have_no_side_effects(self):
        self.assertEqual(self.run_setup("--help").returncode, 0)
        self.assertEqual(self.run_setup("--invalid").returncode, 2)
        self.assertFalse((self.root / "fontawesome").exists())

    def test_existing_icons_verified_without_network_or_replacement(self):
        self.copy_assets()
        extra = self.root / "fontawesome/keep.txt"
        extra.write_text("preserve me")
        self.assertEqual(self.run_setup().returncode, 0)
        self.assertEqual(extra.read_text(), "preserve me")

    def test_invalid_existing_icons_are_not_overwritten(self):
        self.copy_assets()
        icon = self.root / "fontawesome/svgs/solid/phone.svg"
        icon.write_text("invalid")
        self.assertNotEqual(self.run_setup().returncode, 0)
        self.assertEqual(icon.read_text(), "invalid")

    def test_missing_license_is_not_silently_replaced(self):
        self.copy_assets()
        license_file = self.root / "fontawesome/LICENSE.txt"
        license_file.unlink()
        self.assertNotEqual(self.run_setup().returncode, 0)
        self.assertFalse(license_file.exists())


if __name__ == "__main__":
    unittest.main()
