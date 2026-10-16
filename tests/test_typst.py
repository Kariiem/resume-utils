"""Content and coarse layout checks; requires Typst and Poppler."""
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


def source_expectations():
    """Read this résumé's literal calls/bullets, not general Typst syntax.

    Keep this small test reader in sync if the source's structure changes.
    Expectations come from Typst itself; there is no parallel content document.
    """
    source = (ROOT / "resume.typ").read_text()
    parts = re.split(r'#section\("([^"]+)"\)\[', source)
    sections = {}
    for title, body in zip(parts[1::2], parts[2::2]):
        entries = []
        if "#entry(" in body:
            for entry in body.split("#entry(")[1:]:
                header, content = entry.split(")[", 1)
                fields = re.findall(r'"([^"]+)"', header)
                fragments = [field for field in fields if not field.startswith("https://")]
                organization = re.search(r"organization:\s*\[([^\]]+)\]", header)
                if organization:
                    fragments.append(organization[1])
                bullets = re.findall(r"^\s*- (.+)$", content, re.M)
                if not bullets:
                    raise ValueError(f"No bullets found in {fragments[0]}")
                entries.append(fragments + bullets)
        else:
            # Education's grid cells, or the three literal skill rows.
            cells = re.findall(r"\[([^\[\]\n]+)\]", body)
            if cells:
                entries.append(cells)
            else:
                for label, value in re.findall(r"^\s*\*([^*\n]+)\* ([^\n]+)", body, re.M):
                    entries.append([label + " " + value.rstrip().removesuffix("\\").rstrip()])
        if not entries:
            raise ValueError(f"No entries found in {title}")
        sections[title] = entries
    contacts = re.findall(
        r'#contact\(\s*"[^"]+",\s*"[^"]+",\s*"([^"]+)",?\s*\)', source)
    contacts += re.findall(r'smallcaps\[([^\]]+)\]', parts[0])
    contacts += re.findall(r'#text\([^\n)]*\)\[([^\]\n]+)\]', parts[0])
    urls = set(re.findall(r'"((?:https://|mailto:|tel:)[^"]+)"', source))
    return sections, contacts, urls


class TypstTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for command in ("typst", "pdftotext", "pdfinfo"):
            if not shutil.which(command):
                raise unittest.SkipTest(f"Missing optional test dependency: {command}")
        temporary = tempfile.TemporaryDirectory()
        cls.addClassCleanup(temporary.cleanup)
        directory = Path(temporary.name)
        # Build with only the source files and the five external icons.
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
        cls.sections, cls.contacts, cls.expected_urls = source_expectations()

    def test_content_is_rendered(self):
        fragments = self.contacts + list(self.sections)
        fragments += [fragment for entries in self.sections.values()
                      for entry in entries for fragment in entry]
        for fragment in fragments:
            with self.subTest(fragment=fragment):
                self.assertIn(normalize(fragment), self.all_text)

    def test_contact_and_project_link_annotations(self):
        self.assertEqual(self.urls, self.expected_urls)

    def test_sections_remain_in_source_order(self):
        positions = [self.all_text.index(normalize(title)) for title in self.sections]
        self.assertEqual(positions, sorted(positions))

    def test_entries_stay_together_but_sections_may_span_pages(self):
        previous_page = 0
        for entries in self.sections.values():
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
