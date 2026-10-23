#!/usr/bin/env python3
"""Export only the public ClockJoy website, excluding engineering documents."""

from pathlib import Path
import shutil


root = Path(__file__).resolve().parents[1]
source = root / "docs"
destination = root / "tmp" / "clockjoy-site"
site_directories = {"assets", "en", "ja", "ko", "zh-hans", "zh-hant", "guides"}
text_extensions = {".html", ".js", ".css", ".xml", ".txt"}
asset_extensions = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".ico", ".woff", ".woff2"}
files = []

for path in sorted(source.rglob("*")):
    if not path.is_file():
        continue
    relative = path.relative_to(source)
    if len(relative.parts) > 1 and relative.parts[0] not in site_directories:
        continue
    if path.suffix in text_extensions or (
        relative.parts[0] == "assets" and path.suffix in asset_extensions
    ):
        if path.suffix in text_extensions and "payjoy" in path.read_text().lower():
            raise SystemExit(f"Retired public brand remains in {relative}")
        files.append((path, relative))

if destination.exists():
    shutil.rmtree(destination)
destination.mkdir(parents=True)

for path, relative in files:
    target = destination / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, target)

(destination / ".nojekyll").touch()
print(f"Exported {len(files)} public files to {destination}")
