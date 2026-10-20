"""Regenerate launcher assets from the selected re:voca card icon.

Run on macOS: python3 tool/generate_app_icons.py
Uses the system sips utility; no image-generation API or Python packages needed.
The opaque source keeps square corners; each OS applies its own launcher mask.
"""

import json
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/branding/app-icon.png"
ANDROID_RES = ROOT / "android/app/src/main/res"
IOS_ICONS = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"


def resize(destination: Path, size: int) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["sips", "--resampleHeightWidth", str(size), str(size),
         str(SOURCE), "--out", str(destination)],
        check=True,
        capture_output=True,
        text=True,
    )


def main() -> None:
    if not shutil.which("sips"):
        raise SystemExit("This icon generator requires the macOS sips utility.")
    if not SOURCE.is_file():
        raise SystemExit(f"Missing source icon: {SOURCE}")

    outputs = {}
    for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96,
                          "xxhdpi": 144, "xxxhdpi": 192}.items():
        outputs[ANDROID_RES / f"mipmap-{density}/ic_launcher.png"] = size

    # The adaptive-icon XML fits this bitmap into the central 72dp viewport
    # of its 108dp layer, preserving the composition under launcher masks.
    outputs[ANDROID_RES / "drawable-nodpi/ic_launcher_artwork.png"] = 432

    catalog = json.loads((IOS_ICONS / "Contents.json").read_text())
    for item in catalog["images"]:
        size = float(item["size"].split("x")[0])
        scale = int(item["scale"].removesuffix("x"))
        outputs[IOS_ICONS / item["filename"]] = round(size * scale)

    for destination, size in outputs.items():
        resize(destination, size)
    print(f"Generated {len(outputs)} Android and iOS icon assets from {SOURCE}.")


if __name__ == "__main__":
    main()
