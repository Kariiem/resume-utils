"""Offline build.sh integration tests: real ZIP/checksum tools, mocked Docker/Emacs."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile


PROJECT = Path(__file__).resolve().parents[1]
ARCHIVE_HASH = "5717251cdd7b3f3df989f9fada0ca65b6609045c04a0c1bd78fb27acb3bf84cb"
FONT_NAMES = (
    "Font Awesome 7 Brands-Regular-400.otf",
    "Font Awesome 7 Free-Regular-400.otf",
    "Font Awesome 7 Free-Solid-900.otf",
)


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.root = self.base / "project with spaces"
        self.root.mkdir()
        self.fonts = {name: f"fixture: {name}\n".encode() for name in FONT_NAMES}
        self.archive = self.base / "fixture.zip"
        with zipfile.ZipFile(self.archive, "w") as archive:
            prefix = "fontawesome-free-7.2.0-desktop/"
            archive.writestr(prefix + "LICENSE.txt", "fixture license\n")
            for name, data in self.fonts.items():
                archive.writestr(prefix + "otfs/" + name, data)
        # Replace only the archive pin in the disposable project with our fixture
        # hash. Production still pins the real upstream ZIP; no network is used.
        script = (PROJECT / "build.sh").read_text()
        self.assertEqual(script.count(ARCHIVE_HASH), 1)
        (self.root / "build.sh").write_text(script.replace(
            ARCHIVE_HASH, hashlib.sha256(self.archive.read_bytes()).hexdigest()))
        (self.root / "fontawesome.sha256").write_text("".join(
            f"{hashlib.sha256(data).hexdigest()}  fontawesome/otfs/{name}\n"
            for name, data in self.fonts.items()))
        (self.root / "resume.org").write_text("fixture Org\n")
        self.bin = self.base / "bin"
        self.bin.mkdir()
        mock = f"#!{sys.executable}\n" + '''import json, os, pathlib, shutil, sys
name = pathlib.Path(sys.argv[0]).name
with open(os.environ["COMMAND_LOG"], "a") as log:
    log.write(json.dumps({"command": name, "args": sys.argv[1:],
        "fonts": os.environ.get("RESUME_FONTAWESOME_DIR"),
        "image": os.environ.get("RESUME_TEX_IMAGE")}) + "\\n")
if name == "curl":
    shutil.copyfile(os.environ["DOWNLOAD_ARCHIVE"],
                    sys.argv[sys.argv.index("-o") + 1])
if name == "docker" and sys.argv[1] == "info" and os.environ.get("FAIL_DOCKER"):
    sys.exit(1)
'''
        for name in ("curl", "docker", "emacs"):
            path = self.bin / name
            path.write_text(mock)
            path.chmod(0o755)
        self.log = self.base / "commands.jsonl"
        self.env = dict(os.environ)
        for name in ("RESUME_FONTAWESOME_DIR", "RESUME_TEX_IMAGE", "FAIL_DOCKER"):
            self.env.pop(name, None)
        self.env.update(PATH=f"{self.bin}:{os.environ['PATH']}",
                        COMMAND_LOG=str(self.log), DOWNLOAD_ARCHIVE=str(self.archive))

    def install_fonts(self, destination=None):
        destination = destination or self.root / "fontawesome"
        (destination / "otfs").mkdir(parents=True)
        (destination / "LICENSE.txt").write_text("fixture license\n")
        for name, data in self.fonts.items():
            (destination / "otfs" / name).write_bytes(data)
        return destination

    def run_build(self, *args, success=True, cwd=None):
        result = subprocess.run(["bash", str(self.root / "build.sh"), *args],
                                cwd=cwd or self.root, env=self.env,
                                capture_output=True, text=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def commands(self, name=None):
        entries = [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
        return [entry for entry in entries if name is None or entry["command"] == name]

    def assert_no_build(self):
        self.assertFalse(any(c["args"][0] == "build" for c in self.commands("docker")))
        self.assertFalse(self.commands("emacs"))

    def test_existing_fonts_export_without_download(self):
        self.install_fonts()
        self.run_build(cwd=self.base)
        self.assertFalse(self.commands("curl"))
        build = self.commands("docker")[-1]
        self.assertEqual(build["args"], ["build", "--platform", "linux/amd64",
                                         "-t", "resume-tex:local", str(self.root)])
        export = self.commands("emacs")[0]
        self.assertIn(str(self.root / "resume.org"), export["args"])
        self.assertIn("(setq enable-local-variables nil enable-local-eval nil)", export["args"])
        self.assertEqual(export["args"][-2:], ["-f", "resume-export-pdf"])

    def test_download_extract_verify_and_reuse(self):
        self.run_build("--setup-only")
        self.assertEqual(len(self.commands("curl")), 1)
        self.assertIn("https://use.fontawesome.com/releases/v7.2.0/fontawesome-free-7.2.0-desktop.zip",
                      self.commands("curl")[0]["args"])
        for name, data in self.fonts.items():
            self.assertEqual((self.root / "fontawesome/otfs" / name).read_bytes(), data)
        self.assertTrue((self.root / "fontawesome/LICENSE.txt").is_file())
        self.assertFalse(list(self.root.glob(".resume-fontawesome.*")))
        self.run_build("--setup-only")
        self.assertEqual(len(self.commands("curl")), 1)
        self.assertFalse(self.commands("emacs"))

    def test_bad_archive_is_not_extracted_or_installed(self):
        self.archive.write_bytes(b"corrupt download")
        self.run_build("--setup-only", success=False)
        self.assertFalse((self.root / "fontawesome").exists())
        self.assertFalse(list(self.root.glob(".resume-fontawesome.*")))
        self.assert_no_build()

    def test_archive_fonts_must_also_match_manifest(self):
        (self.root / "fontawesome.sha256").write_text(
            "0" * 64 + "  fontawesome/otfs/" + FONT_NAMES[0] + "\n")
        self.run_build("--setup-only", success=False)
        self.assertFalse((self.root / "fontawesome").exists())
        self.assertFalse(list(self.root.glob(".resume-fontawesome.*")))
        self.assert_no_build()

    def test_bad_existing_fonts_are_not_overwritten(self):
        fonts = self.install_fonts()
        bad = fonts / "otfs" / FONT_NAMES[0]
        bad.write_text("locally modified")
        result = self.run_build("--setup-only", success=False)
        self.assertIn("nothing was overwritten", result.stderr)
        self.assertEqual(bad.read_text(), "locally modified")
        self.assertFalse(self.commands("curl"))
        self.assert_no_build()

    def test_existing_fonts_must_retain_license(self):
        fonts = self.install_fonts()
        (fonts / "LICENSE.txt").unlink()
        self.run_build("--setup-only", success=False)
        self.assert_no_build()

    def test_external_fonts_custom_image_and_alternate_cv(self):
        fonts = self.install_fonts(self.base / "external fonts")
        self.env.update(RESUME_FONTAWESOME_DIR=str(fonts) + "/",
                        RESUME_TEX_IMAGE="custom-resume:test")
        cv = self.root / "other" / "family cv.org"
        cv.parent.mkdir()
        cv.write_text("fixture Org\n")
        self.run_build("other/family cv.org")
        export = self.commands("emacs")[0]
        self.assertIn(str(cv), export["args"])
        self.assertEqual(export["fonts"], str(fonts))
        self.assertEqual(export["image"], "custom-resume:test")
        self.assertIn("custom-resume:test", self.commands("docker")[-1]["args"])
        self.assertFalse(self.commands("curl"))

    def test_outside_org_is_rejected(self):
        outside = self.base / "outside.org"
        outside.write_text("fixture Org\n")
        self.run_build(str(outside), success=False)
        self.assertFalse(self.commands())

    def test_relative_external_font_path_is_rejected(self):
        self.env["RESUME_FONTAWESOME_DIR"] = "relative/fonts"
        self.run_build("--setup-only", success=False)
        self.assertFalse(self.commands())

    def test_unavailable_docker_fails_before_download(self):
        self.env["FAIL_DOCKER"] = "1"
        self.run_build("--setup-only", success=False)
        self.assertFalse(self.commands("curl"))
        self.assert_no_build()

    def test_help_and_invalid_arguments_have_no_side_effects(self):
        self.run_build("--help")
        self.run_build("--unknown", success=False)
        self.run_build("--setup-only", "resume.org", success=False)
        self.assertFalse(self.commands())


if __name__ == "__main__":
    unittest.main()
