#!/usr/bin/env python3
"""Render docs/TICKERLINE.md to docs/TICKERLINE.odt. Needs python-markdown and LibreOffice."""
import base64, re, subprocess, tempfile
from pathlib import Path
import markdown

DOCS = Path(__file__).resolve().parent.parent / "docs"
body = markdown.markdown((DOCS / "TICKERLINE.md").read_text(), extensions=["tables", "fenced_code", "toc"])
style = """body{font-family:'IBM Plex Sans',sans-serif;font-size:10pt}
h1,h2,h3{font-family:'Chakra Petch',sans-serif} code,pre{font-family:'BlexMono Nerd Font',monospace;font-size:9pt}
table{border-collapse:collapse} td,th{border:1px solid #999;padding:3px 6px;vertical-align:top} img{max-width:16cm}"""
html = f"<!doctype html><html><head><meta charset='utf-8'><title>Tickerline</title><style>{style}</style></head><body>{body}</body></html>"
# inline the images, or LibreOffice only links them
# with an explicit width, or LibreOffice only links them / lets them run off the page
def inline(m):
    png = (DOCS / m.group(1)).read_bytes()
    w, h = int.from_bytes(png[16:20], "big"), int.from_bytes(png[20:24], "big")
    width = 280 if h > w else 600  # portrait sidebar shots sit two per table row
    return f'width="{width}" src="data:image/png;base64,{base64.b64encode(png).decode()}"'
html = re.sub(r'src="([^"]+\.png)"', inline, html)
# numbered chapters ("1. Quick reference") start on a new page
html = re.sub(r'<h2(?= id="[^"]*">\d+\.)', '<h2 style="page-break-before:always"', html)
src = DOCS / "TICKERLINE.html"
src.write_text(html)
try:
    with tempfile.TemporaryDirectory() as profile:  # own profile: works while LibreOffice is open
        subprocess.run(["soffice", f"-env:UserInstallation=file://{profile}", "--headless", "--infilter=HTML (StarWriter)",
                        "--convert-to", "odt:writer8", "--outdir", str(DOCS), str(src)], check=True)
finally:
    src.unlink()
