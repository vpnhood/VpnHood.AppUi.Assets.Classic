# Cuts the faces only a browser page loads, into assets/browser-fonts/.
#
# A page in a browser draws with the faces it is handed and no others: no browser lends it a system
# font, so the Russian and the Chinese that an app draws with its OS's fonts are boxes there. These two
# faces stand in for them, and only there (AppAssets), since an app needs neither.
#
# Noto Sans goes in with the whole of Cyrillic, which is small. Noto Sans SC is 17 MB whole, so it goes
# in with the words' and the country names' Chinese and the 3,755 common characters of GB2312 level 1:
# what a user types into a box is not known ahead, and the common set covers nearly all of it. A
# character outside the cut draws as a box, though the text under it is what was typed. Both are pinned
# to one weight, which takes about half of what the others would add.
#
# Run it after changing any Chinese words - a new character is a box until it is in the cut - then
# ./_zip-assets.ps1, and commit both. It needs Python with fontTools (pip install fonttools) and fetches
# the two faces, pinned, into the temp folder; the same words and the same sources make the same bytes.
#
# font_cut/zh-country-names.txt is Nager.Country.Translation's names, the ones CountryNames shows, for
# its version 4.7.1: this repo holds no code, so it cannot ask Nager. A newer Nager may rename a country.
#
# The copyright and licence stay in each face's name table, which is where the OFL lets them live.

import hashlib
import json
import pathlib
import sys
import tempfile
import urllib.parse
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = pathlib.Path(__file__).resolve().parent
ASSETS = ROOT / "assets"
TARGET = ASSETS / "browser-fonts"
COUNTRY_NAMES = ROOT / "font_cut" / "zh-country-names.txt"

FONTS_REPO = "https://github.com/google/fonts/raw"
NOTO_SANS = (
    "8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5/ofl/notosans/NotoSans[wdth,wght].ttf",
    "bfb7bb691513f12e734dc346c03a03f784912432d7e3fa8e56efcf906fe86b3d",
)
NOTO_SANS_SC = (
    "a85815a42757630ce188fdad368c2dfc444d4773/ofl/notosanssc/NotoSansSC[wght].ttf",
    "a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da",
)

CYRILLIC_FACE = "NotoSans-Cyrillic.ttf"
HAN_FACE = "NotoSansSC-Common.ttf"
REGULAR_WEIGHT = 400
NORMAL_WIDTH = 100

CYRILLIC = range(0x0400, 0x0530)
CJK_PUNCTUATION = range(0x3000, 0x3040)
FULL_WIDTH_FORMS = range(0xFF00, 0xFFF0)


def is_han(code_point):
    return 0x2E80 <= code_point <= 0x9FFF or 0xF900 <= code_point <= 0xFAFF or 0xFF00 <= code_point <= 0xFFEF


def common_han():
    # GB2312 level 1 is rows 16-55, 0xB0-0xD7 as bytes; the last row stops short
    code_points = set()
    for row in range(0xB0, 0xD8):
        for cell in range(0xA1, 0xFF):
            try:
                code_points.add(ord(bytes((row, cell)).decode("gb2312")))
            except UnicodeDecodeError:
                pass
    return code_points


def text_files():
    return [*sorted((ASSETS / "locales").glob("*.json")), *sorted((ASSETS / "content").rglob("*.md"))]


def page_han():
    texts = [x.read_text(encoding="utf-8") for x in text_files()]
    texts.append(COUNTRY_NAMES.read_text(encoding="utf-8"))
    return {ord(x) for text in texts for x in text if is_han(ord(x))}


def fetch(source):
    path, sha256 = source
    file = pathlib.Path(tempfile.gettempdir()) / "vh-browser-fonts" / f"{sha256}.ttf"
    if not file.exists():
        file.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(f"{FONTS_REPO}/{urllib.parse.quote(path)}") as response:
            file.write_bytes(response.read())

    if hashlib.sha256(file.read_bytes()).hexdigest() != sha256:
        file.unlink()
        raise SystemExit(f"The face is not the pinned one. {path}")
    return file


def cut(source, axes, code_points, face_name):
    # no timestamp of today: a run that changes nothing must leave the bytes as they were
    font = TTFont(fetch(source), recalcTimestamp=False)
    options = subset.Options()
    options.hinting = False
    options.glyph_names = False
    options.notdef_outline = True
    options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14, 16, 17]
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=code_points)
    subsetter.subset(font)
    font = instancer.instantiateVariableFont(font, axes, updateFontNames=True)
    font.save(TARGET / face_name)
    print(f"{face_name}: {len(font.getBestCmap())} characters, {(TARGET / face_name).stat().st_size // 1024} KB.")


# What the words and the country names ask of the faces, as a page loads them. A gap here is a box in
# every user's page, unlike a character someone types.
def check_coverage():
    faces = [*sorted((ASSETS / "fonts").glob("*.ttf")), *sorted(TARGET.glob("*.ttf"))]
    drawn = {x for face in faces for x in TTFont(face, lazy=True).getBestCmap()}
    texts = {x.relative_to(ASSETS).as_posix(): x.read_text(encoding="utf-8") for x in sorted((ASSETS / "locales").glob("*.json"))}
    texts["country names"] = COUNTRY_NAMES.read_text(encoding="utf-8")
    gaps = {}
    for name, text in texts.items():
        missing = sorted({ord(x) for x in text if ord(x) > 0x20} - drawn)
        if missing:
            gaps[name] = " ".join(f"U+{x:04X}" for x in missing)

    if gaps:
        raise SystemExit(f"No face draws these: {json.dumps(gaps, indent=2)}")


TARGET.mkdir(exist_ok=True)
han = common_han() | page_han() | set(CJK_PUNCTUATION) | set(FULL_WIDTH_FORMS)
cut(NOTO_SANS, {"wght": REGULAR_WEIGHT, "wdth": NORMAL_WIDTH}, set(CYRILLIC), CYRILLIC_FACE)
cut(NOTO_SANS_SC, {"wght": REGULAR_WEIGHT}, han, HAN_FACE)
(TARGET / "index.json").write_bytes(json.dumps([CYRILLIC_FACE, HAN_FACE], separators=(",", ":")).encode("utf-8"))
check_coverage()
sys.exit(0)
