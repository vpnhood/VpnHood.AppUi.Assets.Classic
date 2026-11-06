# Cuts assets/fonts/MaterialDesignIcons.ttf to the icons the UI names.
#
# Material Design Icons whole is 1.3 MB, and the UI draws a few dozen of its glyphs, each by the code
# point Mdi.cs (VpnHood.AppUi.Common) names. A glyph left out of the cut is a blank box with no word of
# warning, so add an icon to Mdi.cs, then run this and ./_zip-assets.ps1, and commit both.
#
# It needs Python with fontTools (pip install fonttools) and this store inside the app's checkout, where
# Mdi.cs is, and it fetches the font, pinned, into the temp folder; the same Mdi.cs and the same source
# make the same bytes. The copyright and licence stay in the font's name table.

import hashlib
import logging
import pathlib
import re
import sys
import tempfile
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = pathlib.Path(__file__).resolve().parent
TARGET = ROOT / "assets" / "fonts" / "MaterialDesignIcons.ttf"
MDI = ROOT.parent / "VpnHood.AppUi.Common" / "Mdi.cs"

SOURCE = "https://raw.githubusercontent.com/Templarian/MaterialDesign-Webfont/v7.4.47/fonts/materialdesignicons-webfont.ttf"
SOURCE_SHA256 = "61e8aba5a4e981fe22cf7c8e8bcdbea00476e75c62c37f01bf7ee33361d68428"

# fontTools warns about the source's old timestamps and a stray padding in its post table, every run
logging.disable(logging.WARNING)


def named_code_points():
    if not MDI.exists():
        sys.exit(f"Mdi.cs is not there: this store must sit in the app's checkout. {MDI}")
    code_points = {int(hex_digits, 16) for hex_digits in re.findall(r'public const string \w+ = "\\U([0-9A-F]{8})";', MDI.read_text("utf-8"))}
    if not code_points:
        sys.exit(f"No icon was read from {MDI}; has its form changed?")
    return code_points


def fetch():
    file = pathlib.Path(tempfile.gettempdir()) / "vh-icon-font" / f"{SOURCE_SHA256}.ttf"
    if not file.exists():
        file.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(SOURCE) as response:
            file.write_bytes(response.read())
    if hashlib.sha256(file.read_bytes()).hexdigest() != SOURCE_SHA256:
        file.unlink()
        sys.exit(f"The font fetched is not the one pinned: {SOURCE}")
    return file


def main():
    code_points = named_code_points()
    # The source's bounding boxes start at 0 whatever the outline does, and so do its side bearings. A
    # renderer moves a glyph by the gap between the two, so a recalculated box would shift every icon.
    font = TTFont(fetch(), recalcBBoxes=False, recalcTimestamp=False)
    unknown = code_points - set(font.getBestCmap())
    if unknown:
        sys.exit("Mdi.cs names what the font has not: " + ", ".join(f"U+{code_point:X}" for code_point in sorted(unknown)))

    options = subset.Options()
    options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14, 16, 17]
    subsetter = subset.Subsetter(options)
    subsetter.populate(unicodes=code_points)
    subsetter.subset(font)
    font.save(TARGET)
    print(f"Cut {TARGET.name} to {len(code_points)} icons: {TARGET.stat().st_size} bytes.")


if __name__ == "__main__":
    main()
