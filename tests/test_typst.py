"""Content and coarse layout checks; requires Typst and Poppler, not TeX."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unicodedata
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
NS = {"x": "http://www.w3.org/1999/xhtml"}


def normalize(text):
    text = unicodedata.normalize("NFKC", text)
    text = re.sub(r"(?<=-)\s*\n\s*", "", text)
    text = re.sub(r"[`‘’]", "'", text).replace("–", "-").replace("--", "-")
    return " ".join(text.split())


def org_expectations():
    """Read this CV's simple headings/properties/bullets, not a general exporter."""
    sections, contacts, urls, excluded = {}, [], set(), []
    section, skip, bullet = None, None, []

    def flush():
        if bullet:
            sections[section].append(" ".join(bullet))
            bullet.clear()

    for line in (ROOT / "resume.org").read_text().splitlines():
        heading = re.match(r"^(\*+) (.+)$", line)
        if heading:
            flush()
            level, title = len(heading[1]), heading[2]
            if skip is not None and level <= skip:
                skip = None
            if title.startswith("COMMENT "):
                skip = level if skip is None else skip
                excluded.append(title.removeprefix("COMMENT "))
            elif skip is None:
                if level == 1:
                    section = title
                    sections[section] = []
                else:
                    sections[section].append(title)
        if skip is not None:
            continue
        keyword = re.match(r"^#\+RESUME_(\w+):\s*(.*)$", line)
        if keyword:
            key, value = keyword.groups()
            if key in ("NAME", "LOCATION", "PHONE", "EMAIL", "GITHUB_LABEL"):
                contacts.append(value)
            if key in ("LINKEDIN", "GITHUB"):
                urls.add(value)
            if key == "EMAIL":
                urls.add("mailto:" + value)
            if key == "PHONE_URI":
                urls.add("tel:" + value)
        prop = re.match(r"^:([A-Z_]+):\s*(.*)$", line)
        if prop:
            key, value = prop.groups()
            if key in ("DATE", "QUALIFICATION", "LOCATION", "ORGANIZATION", "VALUE"):
                sections[section].append(value)
            if key == "URL":
                urls.add(value)
        if line.startswith("- "):
            flush()
            bullet.append(line[2:])
        elif bullet and line.startswith("  "):
            bullet.append(line.strip())
        elif bullet:
            flush()
    flush()
    return sections, contacts, urls, excluded


class TypstTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for command in ("typst", "pdftotext", "pdfinfo"):
            if not shutil.which(command):
                raise unittest.SkipTest(f"Missing optional test dependency: {command}")
        temporary = tempfile.TemporaryDirectory()
        cls.addClassCleanup(temporary.cleanup)
        directory = Path(temporary.name)
        # Copy only the Typst files and five external icons; no TeX or font files.
        for name in ("resume.typ", "resume-icon-in-use.typ"):
            shutil.copyfile(ROOT / name, directory / name)
        for name in ("solid/phone", "solid/envelope", "solid/up-right-from-square",
                     "brands/linkedin", "brands/github"):
            relative = Path("fontawesome/svgs") / (name + ".svg")
            target = directory / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        pdf = directory / "resume.pdf"
        subprocess.run([
            "typst", "compile", "--ignore-system-fonts",
            "--package-path", str(directory / "packages"),
            "--package-cache-path", str(directory / "cache"),
            str(directory / "resume.typ"), str(pdf),
        ], check=True, capture_output=True)
        text = subprocess.check_output(["pdftotext", str(pdf), "-"], text=True)
        cls.page_text = [normalize(page) for page in text.split("\f") if page.strip()]
        cls.all_text = " ".join(cls.page_text)
        cls.boxes = ET.fromstring(subprocess.check_output(
            ["pdftotext", "-bbox", str(pdf), "-"])).findall(".//x:page", NS)
        links = subprocess.check_output(["pdfinfo", "-url", str(pdf)], text=True)
        cls.urls = {line.split(maxsplit=2)[2] for line in links.splitlines()[1:]
                    if len(line.split(maxsplit=2)) == 3}
        cls.sections, cls.contacts, cls.expected_urls, cls.excluded = org_expectations()

    def test_all_active_content_and_no_disabled_projects(self):
        fragments = self.contacts + list(self.sections)
        fragments += [item for items in self.sections.values() for item in items]
        for fragment in fragments:
            with self.subTest(fragment=fragment):
                self.assertIn(normalize(fragment), self.all_text)
        for title in self.excluded:
            self.assertNotIn(normalize(title), self.all_text)

    def test_contact_and_project_link_annotations(self):
        self.assertEqual(self.urls, self.expected_urls)

    def test_sections_remain_in_source_order(self):
        positions = [self.all_text.index(normalize(title)) for title in self.sections]
        self.assertEqual(positions, sorted(positions))

    def test_entries_stay_together_but_sections_may_span_pages(self):
        titles = set(re.findall(r"^\*\* (.+)$", (ROOT / "resume.org").read_text(), re.M))
        previous_page = 0
        for items in self.sections.values():
            entries = []
            for item in items:
                if item in titles:
                    entries.append([item])
                else:
                    entries[-1].append(item)
            for entry in entries:
                title = entry[0]
                pattern = r"(?<!\w)" + re.escape(normalize(title)) + r"(?!\w)"
                matches = [i for i, text in enumerate(self.page_text)
                           if re.search(pattern, text)]
                with self.subTest(entry=title):
                    self.assertEqual(len(matches), 1)
                    page = matches[0]
                    self.assertGreaterEqual(page, previous_page)
                    previous_page = page
                    for fragment in entry:
                        self.assertIn(normalize(fragment), self.page_text[page])

    def test_overall_page_format_and_no_clipped_text(self):
        self.assertEqual(len(self.boxes), 2)
        for page in self.boxes:
            self.assertAlmostEqual(float(page.attrib["width"]), 612, delta=1)
            self.assertAlmostEqual(float(page.attrib["height"]), 792, delta=1)
            for word in page.findall("x:word", NS):
                self.assertGreaterEqual(float(word.attrib["xMin"]), 0)
                self.assertGreaterEqual(float(word.attrib["yMin"]), 0)
                self.assertLessEqual(float(word.attrib["xMax"]), 612)
                self.assertLessEqual(float(word.attrib["yMax"]), 792)


if __name__ == "__main__":
    unittest.main()
