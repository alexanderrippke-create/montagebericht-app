"""Read-only PDF QA: validate bounds and render every sample page for review."""
from pathlib import Path
import argparse
import json
import subprocess
import pdfplumber
from PIL import Image, ImageOps, ImageDraw

parser = argparse.ArgumentParser()
parser.add_argument("directory", type=Path)
args = parser.parse_args()
output = args.directory / "pdf-review"
output.mkdir(exist_ok=True)
summary = []
for index, pdf in enumerate(sorted(args.directory.rglob("*.pdf"))):
    label = f"sample-{index+1}"
    with pdfplumber.open(pdf) as document:
        text = "\n".join(page.extract_text() or "" for page in document.pages)
        compact = "".join(text.split())
        for page_number, page in enumerate(document.pages, 1):
            assert abs(page.width - 595.28) < 1 and abs(page.height - 841.89) < 1, "Unexpected page size"
            assert all(c["x0"] >= 24 and c["x1"] <= 571 and c["top"] >= 18 and c["bottom"] <= 829 for c in page.chars), f"Text outside safe page margins: {pdf}, page {page_number}"
        if "ARBEITSENDE" in compact:
            for ending in ["TABELLENENDE", "MATERIALENDE"]:
                assert ending in compact, f"Missing content: {ending}"
        summary.append({"file": str(pdf.relative_to(args.directory)), "pages": len(document.pages), "characters": len(text), "a4": True, "safe_margins": True})
    subprocess.run(["pdftoppm", "-png", "-scale-to", "1100", str(pdf), str(output / label)], check=True, capture_output=True)
    pages = sorted(output.glob(label + "-*.png"))
    thumbs = []
    for page in pages:
        image = Image.open(page).convert("RGB")
        image.thumbnail((380, 538))
        tile = Image.new("RGB", (400, 574), "#e6e9ed")
        tile.paste(image, ((400-image.width)//2, 20))
        ImageDraw.Draw(tile).text((10, 554), page.name, fill="black")
        thumbs.append(tile)
    columns = min(3, len(thumbs))
    sheet = Image.new("RGB", (columns*400, ((len(thumbs)+columns-1)//columns)*574), "white")
    for n, thumbnail in enumerate(thumbs):
        sheet.paste(thumbnail, ((n % columns)*400, (n//columns)*574))
    sheet.save(output / (label + "-overview.png"))
(output / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(summary, ensure_ascii=False, indent=2))
